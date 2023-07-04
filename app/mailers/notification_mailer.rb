# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  helper :accounts,
         :statuses,
         :routing

  before_action :process_params
  before_action :set_status, only: [:mention, :favourite, :reblog]
  before_action :set_account, only: [:follow, :favourite, :reblog, :follow_request]

  default to: -> { email_address_with_name(@user.email, @me.username) }

  def mention
    return unless @user.functional? && @status.present?

    locale_for_account(@me) do
      thread_by_conversation(@status.conversation)
      mail subject: I18n.t('notification_mailer.mention.subject', name: @status.account.acct)
    end
  end

  def follow
    return unless @user.functional?

    locale_for_account(@me) do
      mail subject: I18n.t('notification_mailer.follow.subject', name: @account.acct)
    end
  end

  def favourite
    return unless @user.functional? && @status.present?

    locale_for_account(@me) do
      thread_by_conversation(@status.conversation)
      mail subject: I18n.t('notification_mailer.favourite.subject', name: @account.acct)
    end
  end

  def reblog
    return unless @user.functional? && @status.present?

    locale_for_account(@me) do
      thread_by_conversation(@status.conversation)
      mail subject: I18n.t('notification_mailer.reblog.subject', name: @account.acct)
    end
  end

  def follow_request
    return unless @user.functional?

    locale_for_account(@me) do
      mail subject: I18n.t('notification_mailer.follow_request.subject', name: @account.acct)
    end
  end

  private

  def process_params
    @notification = params[:notification]
    @me = params[:recipient]
    @user = @me.user
    @type = action_name
  end

  def set_status
    @status = @notification.target_status
  end

  def set_account
    @account = @notification.from_account
  end

  def thread_by_conversation(conversation)
    return if conversation.nil?

    msg_id = "<conversation-#{conversation.id}.#{conversation.created_at.strftime('%Y-%m-%d')}@#{Rails.configuration.x.local_domain}>"

    headers['In-Reply-To'] = msg_id
    headers['References']  = msg_id
  end
end
