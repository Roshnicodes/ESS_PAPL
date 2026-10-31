require "openssl"
require "cgi"

# IT Tools: one click from ESS opens Guest House / Help Desk / Training (Key Result portal) or GeoHub
# already signed in – no second login. ESS builds a short-lived signed link that the other app checks:
#
#   Key Result: <KRA_PORTAL_URL>/users/sign_in/<emp_code>?to=<page>&expires_at=<unix>&signature=
#               HMAC-SHA256(KRA_SSO_SECRET, "<emp_code>:<page>:<expires_at>")      (secret = ESS_SSO_SECRET there)
#   GeoHub:     <GEOHUB_URL>/ess/login/<emp_code>?expires_at=<unix>&signature=
#               HMAC-SHA256(GEOHUB_SSO_SECRET, "<emp_code>:<expires_at>")           (secret = ESS_LOGIN_SECRET there)
#   Old ESS:    <OLD_ESS_URL>/ess_sso.php?emp_code=<emp_code>&expires_at=<unix>&signature=
#               HMAC-SHA256(OLD_ESS_SSO_SECRET, "<emp_code>:<expires_at>")          (old_ess_sso/ess_sso.php there)
#               Until its secret is set, the menu simply opens the old ESS login page.
class ExternalAppLink
  VALID_FOR = 2.minutes

  TOOLS = {
    "guest_house" => { label: "Guest House", app: :kra },
    "help_desk"   => { label: "Help Desk",   app: :kra },
    "training"    => { label: "Training",    app: :kra },
    "geohub"      => { label: "GeoHub",      app: :geohub },
    "old_ess"     => { label: "Old ESS",     app: :old_ess }
  }.freeze

  def self.tool?(key) = TOOLS.key?(key.to_s)
  def self.label(key) = TOOLS.dig(key.to_s, :label)

  # Admin sets these in Masters → IT Tools Settings (ENV variables, if present, take priority)
  def self.kra_url    = (AppSetting.get("KRA_PORTAL_URL").presence || "https://kra.ploughmanagro.com").chomp("/")
  def self.geohub_url = (AppSetting.get("GEOHUB_URL").presence || "https://geohub.ploughmanagro.com").chomp("/")
  def self.old_ess_url = (AppSetting.get("OLD_ESS_URL").presence || "https://ess.ploughmanagro.com").chomp("/")

  SECRET_SETTING = { kra: "KRA_SSO_SECRET", geohub: "GEOHUB_SSO_SECRET", old_ess: "OLD_ESS_SSO_SECRET" }.freeze

  def self.secret_for(app) = AppSetting.get(SECRET_SETTING.fetch(app)).to_s

  def self.configured?(key)
    app = TOOLS.dig(key.to_s, :app) or return false
    app == :old_ess || secret_for(app).present?   # old ESS: login page until its secret is set
  end

  # Signed link for this employee, valid for a couple of minutes; nil when the tool is not set up
  def self.url_for(key, user, now: Time.current)
    return nil unless configured?(key)
    code = user.emp_code.to_s.strip
    expires_at = (now + VALID_FOR).to_i
    app = TOOLS[key.to_s][:app]

    if app == :kra
      sig = OpenSSL::HMAC.hexdigest("SHA256", secret_for(:kra), "#{code}:#{key}:#{expires_at}")
      "#{kra_url}/users/sign_in/#{CGI.escape(code)}?#{URI.encode_www_form(to: key, expires_at: expires_at, signature: sig)}"
    elsif app == :old_ess
      return "#{old_ess_url}/" if secret_for(:old_ess).blank?
      sig = OpenSSL::HMAC.hexdigest("SHA256", secret_for(:old_ess), "#{code}:#{expires_at}")
      "#{old_ess_url}/ess_sso.php?#{URI.encode_www_form(emp_code: code, expires_at: expires_at, signature: sig)}"
    else
      sig = OpenSSL::HMAC.hexdigest("SHA256", secret_for(:geohub), "#{code}:#{expires_at}")
      "#{geohub_url}/ess/login/#{CGI.escape(code)}?#{URI.encode_www_form(expires_at: expires_at, signature: sig)}"
    end
  end
end
