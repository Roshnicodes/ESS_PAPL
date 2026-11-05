require "test_helper"

# FY + month filter and the month total on the claim lists.
class ClaimPeriodFilterTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @fin = user("FIN001")
    # one local claim per employee per month, so the two months use two employees
    @oct = approved_local_claim(@emp, Date.new(2026, 10, 1), 500)
    @nov = approved_local_claim(user("MIS001"), Date.new(2026, 11, 1), 300)
    sign_in @fin
  end

  test "without a filter the list behaves exactly as before" do
    get approvals_claims_path(type: "local", scope: "approved")
    assert_response :success
    assert_match "Oct-2026", response.body
    assert_match "Nov-2026", response.body
    assert_match "All months", response.body
  end

  test "a month filter keeps only that month and totals it" do
    get approvals_claims_path(type: "local", scope: "approved", month: "2026-10")
    assert_response :success
    assert_match "Oct-2026", response.body
    assert_no_match(/Nov-2026<\/span>/, response.body)
    assert_match "₹500.00", response.body
    refute_includes totals_card(response.body), "800"
  end

  test "a financial year filter keeps the whole year" do
    get approvals_claims_path(type: "local", scope: "approved", fy: "2026-27")
    assert_response :success
    assert_match "FY 2026-27", response.body
    assert_match "₹800.00", response.body   # 500 + 300
  end

  test "a month outside the chosen year is ignored, the year still applies" do
    get approvals_claims_path(type: "local", scope: "approved", fy: "2025-26", month: "2026-10")
    assert_response :success
    assert_match "FY 2025-26", response.body
    assert_match "₹0.00", response.body
  end

  test "the Excel download carries the filter and ends with a total row" do
    get approvals_claims_path(type: "local", scope: "approved", month: "2026-10", format: :xlsx)
    assert_response :success
    assert_match "local_mileage_claims_approved_2026-27_oct", response.headers["Content-Disposition"]

    get approvals_claims_path(type: "local", scope: "approved", month: "2026-10", format: :csv)
    assert_response :success
    last = response.body.lines.last
    assert_match "TOTAL (Oct-2026)", last
    assert_match "1 claim", last
    assert_match "500.0", last
  end

  test "the pending list shows the filter too and starts unfiltered" do
    sign_in user("AM001")   # L1 of 1025
    get approvals_claims_path(type: "local")
    assert_response :success
    assert_match "Financial year", response.body
    assert_match "All months", response.body

    get approvals_claims_path(type: "local", month: "2026-10")
    assert_response :success
    assert_match "Oct-2026", response.body
  end

  private

  def totals_card(body) = body[/Grand total.{0,200}/m].to_s

  def local_claim(employee, month, amount)
    tour = Tour.new(user: employee, tour_type: "local", general_description: "local travel milage claim")
    tour.save!
    tour.update_columns(claim_month: month, from_date: month, to_date: month.end_of_month)
    claim = TourClaim.build_for(tour.reload)
    claim.claim_local_travels.build(travel_date: month, place_from: "Office", place_to: "Field",
                                    travel_mode: mode("Public Transport"), kilometers: 10, amount: amount, purpose: "Visit")
    claim.bank_account = employee.bank_accounts.first
    claim.save!
    claim
  end

  def approved_local_claim(employee, month, amount)
    claim = local_claim(employee, month, amount)
    coding = finance_mapping
    claim.update_columns(status: "approved", approved_at: Time.current, approved_by_id: @fin.id,
                         project_id: coding.project_id, budget_line_item_id: coding.budget_line_item_id,
                         budget_line_item_code_id: coding.budget_line_item_code_id,
                         l1_approver_id: user("AM001").id, finance_approver_id: @fin.id)
    claim.reload
  end
end
