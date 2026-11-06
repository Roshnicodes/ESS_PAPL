require "test_helper"

# The mails behind Payment Advice and IOM / Circular: who gets one and what is in it.
class PaymentAndIomMailTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @old_url = ENV["ESS_MAIL_RELAY_URL"]
    ENV["ESS_MAIL_RELAY_URL"] = "https://krai.example.org/ess_notification.aspx"
    @admin = user("ADMIN"); @emp = user("1025"); @other = user("AM001")
    @emp.update_columns(email: "emp1025@example.org")
    @other.update_columns(email: "am001@example.org")
  end

  teardown { ENV["ESS_MAIL_RELAY_URL"] = @old_url }

  def mails = enqueued_jobs.select { |j| j["job_class"] == "EssMailJob" }.map { |j| j["arguments"].first }

  test "recording the UTR mails the employee with amount, UTR and a link to the claim" do
    claim = approved_claim!
    claim.user.update_columns(email: "payee@example.org")
    clear_enqueued_jobs
    assert claim.record_payment!(utr: "SBIN0099887", by: user("FIN001"))
    mail = mails.find { |m| m["mail_type"] == "claim_paid" }
    assert mail, "a claim_paid mail is queued"
    assert_equal "payee@example.org", mail["to_email"]
    assert_match "SBIN0099887", mail["message"]
    assert_match "/tours/#{claim.tour_id}/claim", mail["link"]
  end

  test "IOM to selected employees mails only them, with the IOM link and file download links" do
    c = Circular.new(topic_type: "iom", topic: "Leave policy", description: "Updated leave rules.", audience: "selected", created_by: @admin)
    c.circular_recipients.build(user: @emp)
    c.attachments.attach(io: File.open(Rails.root.join("test/fixtures/files/passbook.png")), filename: "leave_policy.png", content_type: "image/png")
    c.save!
    clear_enqueued_jobs
    c.notify!(by: @admin)

    to = mails.select { |m| m["mail_type"] == "circular_published" }.map { |m| m["to_email"] }
    assert_equal [ "emp1025@example.org" ], to
    mail = mails.find { |m| m["mail_type"] == "circular_published" }
    assert_match "/circulars/#{c.id}", mail["link"]
    assert_match %r{/circulars/#{c.id}/attachments/\d+\?download=1}, mail["message"]
    assert_match "leave_policy.png", mail["message"]
  end

  test "IOM to all employees mails every active employee who has an email" do
    c = Circular.create!(topic_type: "circular", topic: "Holiday list", audience: "all", created_by: @admin)
    clear_enqueued_jobs
    c.notify!(by: @admin)
    to = mails.select { |m| m["mail_type"] == "circular_published" }.map { |m| m["to_email"] }
    expected = User.active.where.not(id: @admin.id).where("email LIKE '%@%'").pluck(:email)
    assert_equal expected.sort, to.sort
    assert_includes to, "emp1025@example.org"
  end

  private

  def approved_claim!
    month = Date.current.beginning_of_month
    tour = Tour.new(user: @emp, tour_type: "local", general_description: "local travel milage claim")
    tour.save!
    tour.update_columns(claim_month: month, from_date: month, to_date: month.end_of_month)
    claim = TourClaim.build_for(tour.reload)
    claim.claim_local_travels.build(travel_date: month, place_from: "Office", place_to: "Field",
                                    travel_mode: mode("Public Transport"), kilometers: 10, amount: 250, purpose: "Visit")
    claim.bank_account = @emp.bank_accounts.first
    claim.save!
    coding = finance_mapping
    claim.update_columns(status: "approved", approved_at: Time.current, approved_by_id: user("FIN001").id,
                         project_id: coding.project_id, budget_line_item_id: coding.budget_line_item_id,
                         budget_line_item_code_id: coding.budget_line_item_code_id)
    claim.reload
  end
end
