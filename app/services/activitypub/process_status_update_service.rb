# frozen_string_literal: true

class ActivityPub::ProcessStatusUpdateService < BaseService
  include JsonLdHelper

  def call(status, json)
    @json                      = json
    @uri                       = @json['id']
    @status                    = status
    @account                   = status.account
    @media_attachments_changed = false

    return unless expected_type?

    return if already_updated_more_recently?

    # Only allow processing one create/update per status at a time
    RedisLock.acquire(lock_options) do |lock|
      if lock.acquired?
        Status.transaction do
          create_previous_edit!
          update_media_attachments!
          update_poll!
          update_immediate_attributes!
          update_metadata!
          create_edit!
        end

        queue_poll_notifications!
        reset_preview_card!
        broadcast_updates!
      else
        raise Mastodon::RaceConditionError
      end
    end
  end

  private

  def update_media_attachments!
    previous_media_attachments = @status.media_attachments.to_a
    next_media_attachments     = []

    as_array(@json['attachment']).each do |attachment|
      media_attachment_parser = ActivityPub::Parser::MediaAttachmentParser.new(attachment)

      next if media_attachment_parser.remote_url.blank? || next_media_attachments.size > 4

      begin
        media_attachment   = previous_media_attachments.find { |previous_media_attachment| previous_media_attachment.remote_url == media_attachment_parser.remote_url }
        media_attachment ||= MediaAttachment.new(account: @account, remote_url: media_attachment_parser.remote_url)

        media_attachment.description          = media_attachment_parser.description
        media_attachment.focus                = media_attachment_parser.focus
        media_attachment.thumbnail_remote_url = media_attachment_parser.thumbnail_remote_url
        media_attachment.blurhash             = media_attachment_parser.blurhash
        media_attachment.save!

        next_media_attachments << media_attachment

        next if unsupported_media_type?(media_attachment_parser.file_content_type) || skip_download?

        RedownloadMediaWorker.perform_async(media_attachment.id) if media_attachment.remote_url_previously_changed? || media_attachment.thumbnail_remote_url_previously_changed?
      rescue Addressable::URI::InvalidURIError => e
        Rails.logger.debug "Invalid URL in attachment: #{e}"
      end
    end

    removed_media_attachments = previous_media_attachments - next_media_attachments

    MediaAttachment.where(id: removed_media_attachments.map(&:id)).update_all(status_id: nil)
    MediaAttachment.where(id: next_media_attachments.map(&:id)).update_all(status_id: @status.id)

    @media_attachments_changed = true if previous_media_attachments != @status.media_attachments.reload
  end

  def update_poll!
    previous_poll        = @status.preloadable_poll
    @previous_expires_at = previous_poll&.expires_at

    if equals_or_includes?(@json['type'], 'Question') && (@json['anyOf'].is_a?(Array) || @json['oneOf'].is_a?(Array))
      poll_parser = ActivityPub::Parser::PollParser.new(@json)
      poll        = previous_poll || @account.polls.new(status: @status)

      # If for some reasons the options were changed, it invalidates all previous
      # votes, so we need to remove them
      poll.votes.delete_all if poll_parser.options != poll.options && !poll.new_record?

      poll.last_fetched_at = Time.now.utc
      poll.options         = poll_parser.options
      poll.multiple        = poll_parser.multiple
      poll.expires_at      = poll_parser.expires_at
      poll.voters_count    = poll_parser.voters_count
      poll.cached_tallies  = poll_parser.cached_tallies
      poll.save!

      @status.poll_id = poll.id
    else
      previous_poll&.destroy!
      @status.poll_id = nil
    end

    # Because of both has_one/belongs_to associations on status and poll,
    # poll_id is not updated on the status record here yet
    @media_attachments_changed = true if previous_poll&.id != @status.poll_id
  end

  def update_immediate_attributes!
    @status_parser = ActivityPub::Parser::StatusParser.new(@json)

    @status.text         = @status_parser.text || ''
    @status.spoiler_text = @status_parser.spoiler_text || ''
    @status.sensitive    = @account.sensitized? || @status_parser.sensitive || false
    @status.language     = @status_parser.language || detected_language
    @status.edited_at    = @status_parser.edited_at || Time.now.utc

    @status.save!
  end

  def update_metadata!
    @raw_tags     = []
    @raw_mentions = []
    @raw_emojis   = []

    as_array(@json['tag']).each do |tag|
      if equals_or_includes?(tag['type'], 'Hashtag')
        @raw_tags << tag['name']
      elsif equals_or_includes?(tag['type'], 'Mention')
        @raw_mentions << tag['href']
      elsif equals_or_includes?(tag['type'], 'Emoji')
        @raw_emojis << tag
      end
    end

    update_tags!
    update_mentions!
    update_emojis!
  end

  def update_tags!
    @status.tags = Tag.find_or_create_by_names(@raw_tags)
  end

  def update_mentions!
    previous_mentions = @status.active_mentions.includes(:account).to_a
    current_mentions  = []

    @raw_mentions.each do |href|
      next if href.blank?

      account   = ActivityPub::TagManager.instance.uri_to_resource(href, Account)
      account ||= ActivityPub::FetchRemoteAccountService.new.call(href)

      next if account.nil?

      mention   = previous_mentions.find { |x| x.account_id == account.id }
      mention ||= account.mentions.new(status: @status)

      current_mentions << mention
    end

    current_mentions.each do |mention|
      mention.save if mention.new_record?
    end

    # If previous mentions are no longer contained in the text, convert them
    # to silent mentions, since withdrawing access from someone who already
    # received a notification might be more confusing
    removed_mentions = previous_mentions - current_mentions

    Mention.where(id: removed_mentions.map(&:id)).update_all(silent: true) unless removed_mentions.empty?
  end

  def update_emojis!
    return if skip_download?

    @raw_emojis.each do |raw_emoji|
      custom_emoji_parser = ActivityPub::Parser::CustomEmojiParser.new(raw_emoji)

      next if custom_emoji_parser.shortcode.blank? || custom_emoji_parser.image_remote_url.blank?

      emoji = CustomEmoji.find_by(shortcode: custom_emoji_parser.shortcode, domain: @account.domain)

      next unless emoji.nil? || custom_emoji_parser.image_remote_url != emoji.image_remote_url || (custom_emoji_parser.updated_at && custom_emoji_parser.updated_at >= emoji.updated_at)

      begin
        emoji ||= CustomEmoji.new(domain: @account.domain, shortcode: custom_emoji_parser.shortcode, uri: custom_emoji_parser.uri)
        emoji.image_remote_url = custom_emoji_parser.image_remote_url
        emoji.save
      rescue Seahorse::Client::NetworkingError => e
        Rails.logger.warn "Error storing emoji: #{e}"
      end
    end
  end

  def expected_type?
    equals_or_includes_any?(@json['type'], %w(Note Question))
  end

  def lock_options
    { redis: Redis.current, key: "create:#{@uri}", autorelease: 15.minutes.seconds }
  end

  def detected_language
    LanguageDetector.instance.detect(@status_parser.text, @account)
  end

  def create_previous_edit!
    # We only need to create a previous edit when no previous edits exist, e.g.
    # when the status has never been edited. For other cases, we always create
    # an edit, so the step can be skipped

    return if @status.edits.any?

    @status.edits.create(
      text: @status.text,
      spoiler_text: @status.spoiler_text,
      media_attachments_changed: false,
      account_id: @account.id,
      created_at: @status.created_at
    )
  end

  def create_edit!
    return unless @status.text_previously_changed? || @status.spoiler_text_previously_changed? || @media_attachments_changed

    @status_edit = @status.edits.create(
      text: @status.text,
      spoiler_text: @status.spoiler_text,
      media_attachments_changed: @media_attachments_changed,
      account_id: @account.id,
      created_at: @status.edited_at
    )
  end

  def skip_download?
    return @skip_download if defined?(@skip_download)

    @skip_download ||= DomainBlock.reject_media?(@account.domain)
  end

  def unsupported_media_type?(mime_type)
    mime_type.present? && !MediaAttachment.supported_mime_types.include?(mime_type)
  end

  def already_updated_more_recently?
    @status.edited_at.present? && @json['updated'].present? && @status.edited_at > @json['updated'].to_datetime
  rescue ArgumentError
    false
  end

  def reset_preview_card!
    @status.preview_cards.clear if @status.text_previously_changed? || @status.spoiler_text.present?
    LinkCrawlWorker.perform_in(rand(1..59).seconds, @status.id) if @status.spoiler_text.blank?
  end

  def broadcast_updates!
    ::DistributionWorker.perform_async(@status.id, update: true)
  end

  def queue_poll_notifications!
    poll = @status.preloadable_poll

    # If the poll had no expiration date set but now has, and people have
    # voted, schedule a notification

    if @previous_expires_at.nil? && poll.present? && poll.expires_at.present? && poll.votes.exists?
      PollExpirationNotifyWorker.perform_at(poll.expires_at + 5.minutes, poll.id)
    end
  end
end
