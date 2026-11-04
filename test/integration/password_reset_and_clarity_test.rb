require "test_helper"

class PasswordResetAndClarityTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @emp = user("1025")
    @emp.update_columns(email: "priya@ploughmanagro.com")
    @old_relay = ENV["ESS_MAIL_RELAY_URL"]; ENV["ESS_MAIL_RELAY_URL"] = "https://krai.asaindia.org/papless_notification.aspx"
  end
  teardown { ENV["ESS_MAIL_RELAY_URL"] = @old_relay }

  test "login page links to forgot password; a mailed link sets a new password once" do
    get new_user_session_path
    assert_match new_password_reset_path, response.body

    assert_enqueued_jobs(1, only: EssMailJob) { post password_reset_path, params: { emp_code: "1025" } }
    assert_redirected_to new_user_session_path
    params = enqueued_jobs.find { _1["job_class"] == "EssMailJob" }["arguments"].first
    assert_equal "priya@ploughmanagro.com", params["to_email"]
    assert_equal "password_reset", params["mail_type"]
    link = params["link"]
    assert_match %r{\Ahttps://hr\.asaindia\.org/papl/forgot-password/edit\?token=}, link
    token = Rack::Utils.parse_query(URI(link).query)["token"]

    assert_no_enqueued_jobs(only: EssMailJob) { post password_reset_path, params: { emp_code: "1025" } }   # not twice in 2 minutes

    get edit_password_reset_path(token: token)
    assert_response :success
    patch password_reset_path, params: { token: token, password: "newpass9", password_confirmation: "other" }
    assert_response :unprocessable_entity
    patch password_reset_path, params: { token: token, password: "newpass9", password_confirmation: "newpass9" }
    assert_redirected_to new_user_session_path
    assert @emp.reload.valid_password?("newpass9")

    get edit_password_reset_path(token: token)                          # used once – gone
    assert_redirected_to new_password_reset_path
  end

  test "unknown code or no email: same answer, no mail; expired link refused" do
    @emp.update_columns(email: nil)
    assert_no_enqueued_jobs(only: EssMailJob) do
      post password_reset_path, params: { emp_code: "1025" }
      post password_reset_path, params: { emp_code: "NOPE" }
    end
    assert_redirected_to new_user_session_path

    raw, digest = Devise.token_generator.generate(User, :reset_password_token)
    @emp.update_columns(reset_password_token: digest, reset_password_sent_at: 3.hours.ago)
    get edit_password_reset_path(token: raw)
    assert_redirected_to new_password_reset_path
  end

  test "stamps say what they are about: an approved tour plan next to a claim that is only saved" do
    tour = @emp.tours.create!(send_now: true, from_date: Date.current - 6, to_date: Date.current - 5,
      tour_visits_attributes: [ { visit_date: Date.current - 6, place: "Betul", planned_activity: "TOT" } ])
    tour.approve!(by: @emp.reporting_manager, remark: "ok")
    TourClaim.create!(tour: tour, user: @emp, claim_type: "tour")
    sign_in @emp
    get tour_path(tour)
    body = response.body
    assert_match %r{seal-top">Tour Plan<.*?seal-word">Approved<}m, body
    assert_match %r{seal-top">TA/DA Claim<.*?seal-word">Not sent<}m, body
  end

  test "All Tours: waiting ones first, merely saved ones last" do
    saved = @emp.tours.create!(from_date: Date.current - 30, to_date: Date.current - 29)                      # draft
    waiting = @emp.tours.create!(send_now: true, from_date: Date.current - 20, to_date: Date.current - 19,
      tour_visits_attributes: [ { visit_date: Date.current - 20, place: "Indore", planned_activity: "Mtg" } ])  # pending L1
    saved.update_columns(created_at: 1.minute.from_now)                                                      # newest, still last
    sign_in user("ADMIN")
    get masters_all_tours_path
    assert_operator response.body.index(tour_path(waiting)), :<, response.body.index(tour_path(saved))
  end

  test "claim form: NA is offered in A. Travel and marked as 'no journey'" do
    tour = @emp.tours.create!(send_now: true, from_date: Date.current - 6, to_date: Date.current - 5,
      tour_visits_attributes: [ { visit_date: Date.current - 6, place: "Betul", planned_activity: "TOT" } ])
    tour.approve!(by: @emp.reporting_manager, remark: "ok")
    sign_in @emp
    get new_tour_claim_path(tour)
    assert_response :success
    assert_match %r{<option data-none="true" value="#{mode("NA").id}">NA</option>}, response.body
  end
end
