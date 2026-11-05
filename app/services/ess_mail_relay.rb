require "json"
require "net/http"
require "uri"

# Every in-app notification (bell) is also sent as an email through krai (the server has no SMTP),
# the same way Apurti (Asset Management) and the KRA portal send their mails:
#
#   GET https://krai.asaindia.org/papless_notification.aspx?to_email=...&to_name=...&subject=...&message=...
#       &link=...&employee_name=...&employee_code=...&quarter=&month=&reviewer_role=...&reviewer_name=...
#       &action=...&remarks=...&mail_type=<notification kind>
# (the same parameters krai's KRA / Guest House pages use; tour reference, dates and claim amount go in message)
#
# In production it uses krai's PAPL page (DEFAULT_RELAY_URL; mails go out from notification@ploughmanagro.com).
# ESS_MAIL_RELAY_URL overrides it; elsewhere (development / test) mails are off until it is set,
# so nothing changes before krai has the page. A failed mail is only logged – it never stops
# the approval / claim that created the notification.
class EssMailRelay
  class DeliveryError < StandardError; end

  FIELDS = %w[to_email to_name subject message link employee_name employee_code quarter month
              reviewer_role reviewer_name action remarks mail_type].freeze
  DEFAULT_RELAY_URL = "https://krai.asaindia.org/papless_notification.aspx".freeze
  DEFAULT_APP_URL = "https://hr.asaindia.org/papl".freeze   # mail buttons open PAPL ESS, never ASA ESS
  TIMEOUT_SECONDS = 15
  MAX_REDIRECTS = 3
  KRAI_SENT = /email sent/i
  KRAI_REFUSED = /invalid|missing|not sent|failed|error|not allowed/i

  # mail_type => action word (krai shows it as the status)
  ACTION = {
    "tour_pending" => "pending", "claim_pending" => "pending", "claim_query" => "pending",
    "tour_forwarded" => "forwarded", "claim_forwarded" => "forwarded",
    "tour_approved" => "approved", "claim_approved" => "approved",
    "tour_returned" => "returned", "claim_returned" => "returned",
    "tour_rejected" => "rejected", "claim_rejected" => "rejected",
    "tour_cancelled" => "cancelled", "tour_deleted" => "deleted", "claim_closed" => "closed",
    "tour_info" => "information", "claim_info" => "information", "claim_query_info" => "information",
    "circular_published" => "information", "claim_paid" => "approved"
  }.freeze

  def self.url = (ENV["ESS_MAIL_RELAY_URL"].presence || (Rails.env.production? ? DEFAULT_RELAY_URL : "")).to_s.strip
  def self.enabled? = url.present?
  # Forgot-password mail must work even where ordinary notification mail is off (no ESS_MAIL_RELAY_URL outside
  # production); ESS_PASSWORD_RESET_MAIL_RELAY_URL overrides. Ordinary notifications stay as they are.
  def self.password_reset_url
    ENV["ESS_PASSWORD_RESET_MAIL_RELAY_URL"].presence || url.presence || DEFAULT_RELAY_URL
  end
  def self.app_url = (ENV["ESS_MAIL_APP_URL"].presence || DEFAULT_APP_URL).chomp("/")

  # Queues the mail for one notification; never raises.
  def self.notify(notification)
    return false unless enabled?
    params = params_for(notification)
    return false unless params["to_email"].include?("@")

    EssMailJob.perform_later(params)
    true
  rescue StandardError => error
    Rails.logger.error("EssMailRelay could not queue notification=#{notification.id}: #{error.class} #{error.message}")
    false
  end

  def self.params_for(n)
    item  = n.notifiable
    tour  = item.is_a?(Tour) ? item : item.try(:tour)
    claim = item.is_a?(TourClaim) ? item : nil
    owner = item.try(:user)
    body, remark = split_remark(n.body.to_s)
    details = [
      ("Ref: #{tour.reference_no}" if tour&.reference_no.present?),
      (tour && (tour.type_local? ? "Local Mileage #{tour.claim_month&.strftime('%b-%Y')}" : "Tour Plan #{tour.duration_label}")),
      (format("Claim amount: Rs. %.2f", claim.grand_total.to_d) if claim)
    ].compact
    {
      "to_email"      => n.user.email.to_s.strip,
      "to_name"       => n.user.name.to_s,
      "subject"       => "PAPL ESS: #{n.title}".squish.first(200),
      "message"       => [ body.sub(/[.\s]+\z/, ""), details.join(" | ") ].reject(&:blank?).join(". ").squish,
      "link"          => n.url.to_s.start_with?("http") ? n.url.to_s : "#{app_url}#{n.url}",
      "employee_name" => owner&.name.to_s,
      "employee_code" => owner&.emp_code.to_s,
      "quarter"       => "",
      "month"         => "",
      "reviewer_role" => n.actor ? (n.actor == owner ? "Employee" : "Approver") : "",
      "reviewer_name" => n.actor&.name.to_s,
      "action"        => ACTION.fetch(n.kind.to_s, "information"),
      "remarks"       => remark.to_s,
      "mail_type"     => n.kind.to_s
    }
  end

  # Notifier appends the remark as ' – “…”'; krai shows it in its own Remarks row
  def self.split_remark(text)
    m = text.match(/\A(.*) – “(.*)”\z/m)
    m ? [ m[1], m[2] ] : [ text, nil ]
  end

  def self.request_uri(params, relay_url: url)
    uri = URI.parse(relay_url)
    uri.query = URI.encode_www_form(params.slice(*FIELDS))
    uri
  end

  def self.deliver!(params, relay_url: url)
    raise DeliveryError, "Mail relay URL is not configured" if relay_url.blank?

    response, final_uri = fetch(request_uri(params, relay_url: relay_url))
    where = "[#{final_uri.scheme}://#{final_uri.host}#{final_uri.path}]"
    raise DeliveryError, "Mail service asked for a login #{where}" if final_uri.path.to_s.downcase.match?(/login|signin/)
    raise DeliveryError, "#{failure_message(response)} #{where}" unless success?(response)

    Rails.logger.info("EssMailRelay sent type=#{params['mail_type']} to=#{params['to_email']} status=#{response.code} krai_said=#{reply_text(response).inspect}")
    true
  end

  def self.fetch(uri)
    response = get(uri)
    MAX_REDIRECTS.times do
      break unless response.is_a?(Net::HTTPRedirection) && response["location"].present?
      uri = URI.join(uri.to_s, response["location"])
      response = get(uri)
    end
    [ response, uri ]
  end

  def self.get(uri)
    request = Net::HTTP::Get.new(uri.request_uri)
    request["Accept"] = "application/json"
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
      http.request(request)
    end
  end

  # 200 {"success":true} = sent. krai pages may also answer plain HTML text.
  def self.success?(response)
    return false unless response.is_a?(Net::HTTPSuccess)
    body = parsed_body(response)
    unless body.is_a?(Hash)
      text = reply_text(response)
      return text.match?(KRAI_SENT) || !text.match?(KRAI_REFUSED)
    end
    return false if body.key?("success") && !ActiveModel::Type::Boolean.new.cast(body["success"])
    !body["status"].to_s.downcase.in?(%w[error failed failure])
  end

  def self.failure_message(response)
    body = parsed_body(response)
    detail = body["message"] || body["error"] if body.is_a?(Hash)
    "Mail service returned #{response.code}: #{(detail || reply_text(response)).presence || response.message}"
  end

  def self.reply_text(response)
    response.body.to_s.gsub(%r{<(script|style)[^>]*>.*?</\1>}mi, " ").gsub(/<[^>]+>/, " ").squish.first(200)
  end

  def self.parsed_body(response)
    JSON.parse(response.body.to_s)
  rescue JSON::ParserError
    nil
  end
end
