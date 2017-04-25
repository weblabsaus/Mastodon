# frozen_string_literal: true

require 'csv'

class ImportWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: false

  attr_reader :import

  def perform(import_id)
    @import = Import.find(import_id)

    case @import.type
    when 'blocking'
      process_blocks
    when 'following'
      process_follows
    when 'muting'
      process_mutes
    when 'favourites'
      process_favourites
    end

    @import.destroy
  end

  private

  def from_account
    @import.account
  end

  def import_contents
    Paperclip.io_adapters.for(@import.data).read
  end

  def import_rows
    CSV.new(import_contents).reject(&:blank?)
  end

  def process_mutes
    import_rows.each do |row|
      begin
        target_account = FollowRemoteAccountService.new.call(row.first)
        next if target_account.nil?
        MuteService.new.call(from_account, target_account)
      rescue Goldfinger::Error, HTTP::Error, OpenSSL::SSL::SSLError
        next
      end
    end
  end

  def process_blocks
    import_rows.each do |row|
      begin
        target_account = FollowRemoteAccountService.new.call(row.first)
        next if target_account.nil?
        BlockService.new.call(from_account, target_account)
      rescue Goldfinger::Error, HTTP::Error, OpenSSL::SSL::SSLError
        next
      end
    end
  end

  def process_follows
    import_rows.each do |row|
      begin
        FollowService.new.call(from_account, row.first)
      rescue Mastodon::NotPermittedError, ActiveRecord::RecordNotFound, Goldfinger::Error, HTTP::Error, OpenSSL::SSL::SSLError
        next
      end
    end
  end

  def process_favourites
    import_rows.each do |row|
      begin
        domain, account, id = row

        if domain == Rails.configuration.x.local_domain
          status = Status.find(id)
        else
          status = FetchRemoteStatusService.new.call("http://#{domain}/users/#{account}/#{id}.atom")
        end

        FavouriteService.new.call(from_account, status)
      rescue Mastodon::NotPermittedError, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, Goldfinger::Error, HTTP::Error, OpenSSL::SSL::SSLError
        next
      end
    end
  end
end
