class Settings::Preferences::AppearanceController < Settings::PreferencesController
  private

  def after_update_redirect_path
    settings_preferences_appearance_path
  end
end
