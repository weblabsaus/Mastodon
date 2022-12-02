# frozen_string_literal: true

module Settings
  class TwoFactorAuthenticationMethodsController < BaseController
    include ChallengableConcern

    skip_before_action :require_functional!

    before_action :require_challenge!, only: :disable
    before_action :require_two_factor_enabled, only: :disable

    def index; end

    def disable
      current_user.disable_two_factor!
      UserMailer.two_factor_disabled(current_user).deliver_later!

      redirect_to settings_two_factor_authentication_methods_path, flash: { notice: I18n.t('two_factor_authentication.disabled_success') }
    end

    private

    def require_two_factor_enabled
      redirect_to settings_otp_authentication_path unless current_user.two_factor_enabled?
    end
  end
end
