class Form::TwoFactorConfirmation
  include ActiveModel::Model

  attr_accessor :otp_attempt
end
