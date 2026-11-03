require "test_helper"

class LocalBadgeAndDashboardTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @l1 = user("AM001")
  end

  test "L1 history shows a forwarded claim at its real stage; mileage badge says 'Approved' only after final approval" do
    sign_in @emp
    period = LocalMileagePeriod.new(@emp)
    post local_mileage_path, params: { commit_action: "submit", tour_claim: { bank_account_id: @emp.bank_accounts.first.id,
      claim_local_travels_attributes: { "0" => { travel_date: period.from_date, place_from: "HO", place_to: "Bank",
                                                 travel_mode_id: mode("Four Wheeler").id, meter_from: 100, meter_to: 110 } } } }
    claim = TourClaim.where(claim_type: "local").last
    assert claim.submitted?, claim.status

    sign_out @emp
    sign_in @l1
    patch forward_approvals_claim_path(claim), params: { remark: "ok" }
    assert_not claim.reload.submitted?
    assert_not claim.approved?

    get approvals_claims_path(type: "local", scope: "approved")
    assert_match approvals_claim_path(claim), response.body              # L1's history shows it right after forwarding
    assert_match "Forwarded to", response.body                           # with the real stage, not "Approved"

    sign_out @l1
    sign_in @emp
    get tour_path(claim.tour)
    badge = response.body[/badge badge-dot[^>]*>([^<]+)</, 1]
    assert_not_equal "Approved", badge
  end

  test "dashboard lists the colleagues on tour today" do
    t = @emp.tours.create!(from_date: Date.current, to_date: Date.current + 1, send_now: true,
      tour_visits_attributes: [ { visit_date: Date.current, place: "Jhabua", planned_activity: "Visit" } ])
    t.update_columns(status: "approved", approved_at: Time.current, decided_by_id: @l1.id)
    sign_in @l1
    get authenticated_root_path
    assert_match 'id="on-tour-today"', response.body
    assert_match "Jhabua", response.body
  end
end
