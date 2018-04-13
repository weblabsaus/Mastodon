# frozen_string_literal: true

class Api::Web::PushSubscriptionsController < Api::BaseController
  respond_to :json

  before_action :require_user!
  protect_from_forgery with: :exception

  def create
    active_session = current_session

    unless active_session.web_push_subscription.nil?
      active_session.web_push_subscription.destroy!
      active_session.update!(web_push_subscription: nil)
    end

    # Mobile devices do not support regular notifications, so we enable push notifications by default
    alerts_enabled = active_session.detection.device.mobile? || active_session.detection.device.tablet?

    data = {
      alerts: {
        follow: alerts_enabled,
        favourite: alerts_enabled,
        reblog: alerts_enabled,
        mention: alerts_enabled,
      },
    }

    data.deep_merge!(data_params) if params[:data]

    web_subscription = ::Web::PushSubscription.create!(
      endpoint: subscription_params[:endpoint],
      key_p256dh: subscription_params[:keys][:p256dh],
      key_auth: subscription_params[:keys][:auth],
      data: data
    )

    active_session.update!(web_push_subscription: web_subscription)

    render json: web_subscription.as_payload
  end

  def update
    params.require([:id])

    web_subscription = ::Web::PushSubscription.find(params[:id])

    web_subscription.update!(data: data_params)

    render json: web_subscription.as_payload
  end

  private

  def subscription_params
    @subscription_params ||= params.require(:subscription).permit(:endpoint, keys: [:auth, :p256dh])
  end

  def data_params
    @data_params ||= params.require(:data).permit(:alerts)
  end
end
