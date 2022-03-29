# frozen_string_literal: true

class NotifyService < BaseService
  def call(recipient, type, activity)
    @recipient    = recipient
    @activity     = activity
    @notification = Notification.new(account: @recipient, type: type, activity: @activity)

    return if recipient.user.nil? || blocked?

    create_notification!
    push_notification!
    push_to_conversation! if direct_message?
    send_email! if email_enabled?
  rescue ActiveRecord::RecordInvalid
    nil
  end

  private

  def blocked_mention?
    FeedManager.instance.filter?(:mentions, @notification.mention.status, @recipient)
  end

  def following_sender?
    return @following_sender if defined?(@following_sender)
    @following_sender = @recipient.following?(@notification.from_account) || @recipient.requested?(@notification.from_account)
  end

  def optional_non_follower?
    @recipient.user.settings.interactions['must_be_follower']  && !@notification.from_account.following?(@recipient)
  end

  def optional_non_following?
    @recipient.user.settings.interactions['must_be_following'] && !following_sender?
  end

  def message?
    @notification.type == :mention
  end

  def direct_message?
    message? && @notification.target_status.direct_visibility?
  end

  # Returns true if the sender has been mentioned by the recipient up the thread
  def response_to_recipient?
    return false if @notification.target_status.in_reply_to_id.nil?

    # Using an SQL CTE to avoid unneeded back-and-forth with SQL server in case of long threads
    !Status.count_by_sql([<<-SQL.squish, id: @notification.target_status.in_reply_to_id, recipient_id: @recipient.id, sender_id: @notification.from_account.id]).zero?
      WITH RECURSIVE ancestors(id, in_reply_to_id, mention_id, path) AS (
          SELECT s.id, s.in_reply_to_id, m.id, ARRAY[s.id]
          FROM statuses s
          LEFT JOIN mentions m ON m.silent = FALSE AND m.account_id = :sender_id AND m.status_id = s.id
          WHERE s.id = :id
        UNION ALL
          SELECT s.id, s.in_reply_to_id, m.id, st.path || s.id
          FROM ancestors st
          JOIN statuses s ON s.id = st.in_reply_to_id
          LEFT JOIN mentions m ON m.silent = FALSE AND m.account_id = :sender_id AND m.status_id = s.id
          WHERE st.mention_id IS NULL AND NOT s.id = ANY(path)
      )
      SELECT COUNT(*)
      FROM ancestors st
      JOIN statuses s ON s.id = st.id
      WHERE st.mention_id IS NOT NULL AND s.visibility = 3
    SQL
  end

  def from_staff?
    @notification.from_account.local? && @notification.from_account.user.present? && @notification.from_account.user.staff?
  end

  def optional_non_following_and_direct?
    direct_message? &&
      @recipient.user.settings.interactions['must_be_following_dm'] &&
      !following_sender? &&
      !response_to_recipient?
  end

  def hellbanned?
    @notification.from_account.silenced? && !following_sender?
  end

  def from_self?
    @recipient.id == @notification.from_account.id
  end

  def domain_blocking?
    @recipient.domain_blocking?(@notification.from_account.domain) && !following_sender?
  end

  def blocked?
    blocked   = @recipient.suspended?                            # Skip if the recipient account is suspended anyway
    blocked ||= from_self? && @notification.type != :poll        # Skip for interactions with self

    return blocked if message? && from_staff?

    blocked ||= domain_blocking?
    blocked ||= @recipient.blocking?(@notification.from_account)
    blocked ||= @recipient.muting_notifications?(@notification.from_account)
    blocked ||= hellbanned?
    blocked ||= optional_non_follower?
    blocked ||= optional_non_following?
    blocked ||= optional_non_following_and_direct?
    blocked ||= conversation_muted?
    blocked ||= blocked_mention? if @notification.type == :mention
    blocked
  end

  def conversation_muted?
    if @notification.target_status
      @recipient.muting_conversation?(@notification.target_status.conversation)
    else
      false
    end
  end

  def create_notification!
    @notification.save!
  end

  def push_notification!
    return if @notification.activity.nil?

    Redis.current.publish("timeline:#{@recipient.id}:notifications", Oj.dump(event: :notification, payload: InlineRenderer.render(@notification, @recipient, :notification)))
    send_push_notifications!
  end

  def push_to_conversation!
    return if @notification.activity.nil?
    AccountConversation.add_status(@recipient, @notification.target_status)
  end

  def send_push_notifications!
    subscriptions_ids = ::Web::PushSubscription.where(user_id: @recipient.user.id)
                                               .select { |subscription| subscription.pushable?(@notification) }
                                               .map(&:id)

    ::Web::PushNotificationWorker.push_bulk(subscriptions_ids) do |subscription_id|
      [subscription_id, @notification.id]
    end
  end

  def send_email!
    return if @notification.activity.nil?
    NotificationMailer.public_send(@notification.type, @recipient, @notification).deliver_later(wait: 2.minutes)
  end

  def email_enabled?
    @recipient.user.settings.notification_emails[@notification.type.to_s]
  end
end
