require "test_helper"

class EssMailRelayTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @emp = user("1025"); @l1 = @emp.reporting_manager
    @l1.update_columns(email: "l1.manager@ploughmanagro.com")
  end

  def with_relay(url = "https://krai.ploughmanagro.com/ess_notification.aspx")
    old = ENV["ESS_MAIL_RELAY_URL"]; ENV["ESS_MAIL_RELAY_URL"] = url
    yield
  ensure
    ENV["ESS_MAIL_RELAY_URL"] = old
  end

  def send_tour
    @emp.tours.create!(send_now: true, from_date: Date.current + 20, to_date: Date.current + 21,
      tour_visits_attributes: [ { visit_date: Date.current + 20, place: "Sehore", planned_activity: "Mtg" } ])
  end

  test "off until ESS_MAIL_RELAY_URL is set" do
    assert_no_enqueued_jobs(only: EssMailJob) { send_tour }
  end

  test "every notification queues one mail with the tour details" do
    with_relay do
      tour = nil
      assert_enqueued_jobs(1, only: EssMailJob) { tour = send_tour }   # L1 has an email; employee gets no bell at send
      params = enqueued_jobs.find { |j| j["job_class"] == "EssMailJob" }["arguments"].first
      assert_equal "l1.manager@ploughmanagro.com", params["to_email"]
      assert_equal "tour_pending", params["mail_type"]
      assert_includes params["message"], tour.reference_no
      assert_equal @emp.emp_code, params["employee_code"]
      assert_equal "pending", params["action"]
      assert_equal %w[to_email to_name subject message link employee_name employee_code quarter month reviewer_role reviewer_name action remarks mail_type].sort, params.except("_aj_symbol_keys").keys.sort
      assert_match %r{\Ahttps://hr\.ploughmanagro\.com/approvals/tours/#{tour.id}\z}, params["link"]
      assert params["subject"].start_with?("PAPL ESS:")
      uri = EssMailRelay.request_uri(params)
      assert_equal "/ess_notification.aspx", uri.path
      assert_includes uri.query, "mail_type=tour_pending"
    end
  end

  test "people without an email get only the bell" do
    @l1.update_columns(email: nil)
    with_relay { assert_no_enqueued_jobs(only: EssMailJob) { send_tour } }
  end

  test "remark goes to its own field" do
    assert_equal [ "Tour approved by X", "Good" ], EssMailRelay.split_remark("Tour approved by X – “Good”")
    assert_equal [ "No remark", nil ], EssMailRelay.split_remark("No remark")
  end

  test "krai answers are read correctly" do
    ok   = Net::HTTPOK.new("1.1", "200", "OK").tap { |r| r.instance_variable_set(:@body, '{"success":true,"message":"Email sent"}'); r.instance_variable_set(:@read, true) }
    fail = Net::HTTPOK.new("1.1", "200", "OK").tap { |r| r.instance_variable_set(:@body, '{"success":false,"message":"to_email invalid"}'); r.instance_variable_set(:@read, true) }
    html = Net::HTTPOK.new("1.1", "200", "OK").tap { |r| r.instance_variable_set(:@body, "<p>Email sent successfully</p>"); r.instance_variable_set(:@read, true) }
    assert EssMailRelay.success?(ok)
    refute EssMailRelay.success?(fail)
    assert EssMailRelay.success?(html)
  end
end
