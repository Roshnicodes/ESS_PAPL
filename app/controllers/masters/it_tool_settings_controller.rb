# Admin: addresses and single sign-on secrets for IT Tools (Key Result portal, GeoHub).
# A secret field left blank keeps the saved value; secrets are stored encrypted and never shown again.
class Masters::ItToolSettingsController < ApplicationController
  before_action { raise CanCan::AccessDenied, "Only admin can change IT Tools settings" unless current_user.admin? }

  FIELDS = {
    "KRA_PORTAL_URL"    => [ "Key Result portal address", "https://kra.ploughmanagro.com" ],
    "KRA_SSO_SECRET"    => [ "Key Result secret (ESS_SSO_SECRET on the Key Result server)", nil ],
    "GEOHUB_URL"        => [ "GeoHub address", "https://geohub.ploughmanagro.com" ],
    "GEOHUB_SSO_SECRET" => [ "GeoHub secret (ESS_LOGIN_SECRET on the GeoHub server)", nil ],
    "OLD_ESS_URL"        => [ "Old ESS address", "https://ess.ploughmanagro.com" ],
    "OLD_ESS_SSO_SECRET" => [ "Old ESS secret (same value inside ess_sso.php on the old ESS) – blank = old ESS opens its login page", nil ]
  }.freeze

  def show
    @suggested_secret = SecureRandom.hex(32)
  end

  def update
    changed = []
    FIELDS.each_key do |key|
      value = params.dig(:settings, key).to_s.strip
      next if key.in?(AppSetting::SECRET_KEYS) && value.blank? && !params.dig(:clear, key).present?
      next if !key.in?(AppSetting::SECRET_KEYS) && value == AppSetting.get(key).to_s
      AppSetting.set!(key, value, by: current_user)
      changed << key
    end
    current_user.log_activity!(:it_tool_settings_changed, details: { keys: changed }) if changed.any?
    redirect_to masters_it_tool_settings_path, notice: changed.any? ? "Saved: #{changed.join(', ')}." : "Nothing changed."
  end
end
