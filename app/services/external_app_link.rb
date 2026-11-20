require "openssl"
require "cgi"

# IT Tools: one click from ESS opens Guest House / Help Desk / Training (Key Result portal) or Old ESS
# already signed in – no second login. ESS builds a short-lived signed link that the other app checks:
#
#   Key Result: <KRA_PORTAL_URL>/users/sign_in/<emp_code>?to=<page>&expires_at=<unix>&signature=
#               HMAC-SHA256(KRA_SSO_SECRET, "<emp_code>:<page>:<expires_at>")      (secret = ESS_SSO_SECRET there)
#   Old ESS:    <OLD_ESS_URL>/ess_sso.php?emp_code=<emp_code>&expires_at=<unix>&signature=
#               HMAC-SHA256(OLD_ESS_SSO_SECRET, "<emp_code>:<expires_at>")          (old_ess_sso/ess_sso.php there)
#               Until its secret is set, the menu simply opens the old ESS login page (<OLD_ESS_URL>/index.php).
#   KRA:        <ASA_KRA_URL>/users/ess_sign_in/<emp_code>?expires_at=<unix>&signature=
#               HMAC-SHA256(ASA_KRA_SSO_SECRET, "<emp_code>:<expires_at>")         (secret = ESS_SSO_SECRET on the KRA server)
#               PAPL: no default address – "Soon" in the menu until admin sets address and secret.
#   Exam:       a plain link (EXAM_URL) – the exam portal has its own HR login; shown only to PD HR / admin
#               and the employee codes in EXAM_ACCESS_CODES.
class ExternalAppLink
  VALID_FOR = 2.minutes

  # Leave is applied for in HROne – a plain link, no single sign-on.
  # Admin can point it somewhere else from Masters → IT Tools Settings (key LEAVE_URL).
  LEAVE_URL = "https://app.hrone.cloud/app/request/initiate-leave".freeze

  TOOLS = {
    "guest_house" => { label: "Guest House", app: :kra },
    "help_desk"   => { label: "Help Desk",   app: :kra },
    "training"    => { label: "Training",    app: :kra },
    "old_ess"     => { label: "Old ESS",     app: :old_ess },
    "asa_kra"     => { label: "KRA",         app: :asa_kra },
    "exam"        => { label: "Exam",        app: :exam }
  }.freeze

  EXAM_DEFAULT_CODES = "".freeze   # PAPL: only PD HR / admin unless admin lists more codes in IT Tools Settings

  def self.tool?(key) = TOOLS.key?(key.to_s)
  def self.label(key) = TOOLS.dig(key.to_s, :label)

  # Admin sets these in Masters → IT Tools Settings (ENV variables, if present, take priority)
  def self.kra_url    = (AppSetting.get("KRA_PORTAL_URL").presence || "https://kra.ploughmanagro.com").chomp("/")
  def self.old_ess_url = (AppSetting.get("OLD_ESS_URL").presence || "https://ess.asaindia.org/papl").chomp("/")
  def self.asa_kra_url = AppSetting.get("ASA_KRA_URL").to_s.strip.chomp("/").presence   # PAPL: set by admin, no default
  def self.exam_url    = AppSetting.get("EXAM_URL").to_s.strip.chomp("/").presence

  # Who sees a tool in the menu (and may open it). Exam: PD HR / admin + the listed employee codes.
  def self.visible?(key, user)
    return false unless tool?(key)
    return true unless key.to_s == "exam"
    return true if user.hr?
    codes = (AppSetting.get("EXAM_ACCESS_CODES").presence || EXAM_DEFAULT_CODES).split(/[,;\s]+/).map { |c| c.strip.downcase }
    codes.include?(user.emp_code.to_s.strip.downcase)
  end

  SECRET_SETTING = { kra: "KRA_SSO_SECRET", old_ess: "OLD_ESS_SSO_SECRET", asa_kra: "ASA_KRA_SSO_SECRET" }.freeze

  def self.secret_for(app) = AppSetting.get(SECRET_SETTING.fetch(app)).to_s

  def self.configured?(key)
    app = TOOLS.dig(key.to_s, :app) or return false
    return exam_url.present? if app == :exam
    return asa_kra_url.present? && secret_for(app).present? if app == :asa_kra   # PAPL: no default KRA address
    app == :old_ess || secret_for(app).present?   # old ESS: login page until its secret is set
  end

  # Signed link for this employee, valid for a couple of minutes; nil when the tool is not set up
  def self.url_for(key, user, now: Time.current)
    return nil unless configured?(key)
    code = user.emp_code.to_s.strip
    expires_at = (now + VALID_FOR).to_i
    app = TOOLS[key.to_s][:app]

    return exam_url if app == :exam
    if app == :asa_kra
      sig = OpenSSL::HMAC.hexdigest("SHA256", secret_for(:asa_kra), "#{code}:#{expires_at}")
      return "#{asa_kra_url}/users/ess_sign_in/#{CGI.escape(code)}?#{URI.encode_www_form(expires_at: expires_at, signature: sig)}"
    end

    if app == :kra
      sig = OpenSSL::HMAC.hexdigest("SHA256", secret_for(:kra), "#{code}:#{key}:#{expires_at}")
      "#{kra_url}/users/sign_in/#{CGI.escape(code)}?#{URI.encode_www_form(to: key, expires_at: expires_at, signature: sig)}"
    else
      return "#{old_ess_url}/index.php" if secret_for(:old_ess).blank?
      sig = OpenSSL::HMAC.hexdigest("SHA256", secret_for(:old_ess), "#{code}:#{expires_at}")
      "#{old_ess_url}/ess_sso.php?#{URI.encode_www_form(emp_code: code, expires_at: expires_at, signature: sig)}"
    end
  end
end
