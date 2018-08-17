# frozen_string_literal: true

class REST::CredentialAccountSerializer < REST::AccountSerializer
  attributes :source

  def source
    user = object.user

    {
      privacy: user.setting_default_privacy,
      sensitive: user.setting_default_sensitive,
      language: user.setting_default_language,
      filter_bots: user.setting_filter_bots,
      note: object.note,
      fields: object.fields.map(&:to_h),
    }
  end
end
