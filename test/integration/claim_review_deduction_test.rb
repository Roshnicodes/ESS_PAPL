require "test_helper"

class ClaimReviewDeductionTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @l1 = user("AM001")
    @emp.update!(l2_manager: nil)
    t = @emp.tours.create!(send_now: true, from_date: Date.current - 5, to_date: Date.current - 4,
      tour_visits_attributes: [ { visit_date: Date.current - 5, place: "Sehore", planned_activity: "Mtg" } ])
    t.approve!(by: @l1)
    @claim = with_tasks(TourClaim.build_for(t))
    @claim.claim_incidentals.build(expense_date: t.from_date, particular: "Tea", amount: 200)
    @claim.save!
    @claim.submit!(by: @emp)
    @line = @claim.claim_incidentals.first
  end

  test "deduction typed on the review page is saved together with Forward" do
    sign_in @l1
    get approvals_claim_path(@claim)
    assert_match "data-review-deduction", response.body
    patch forward_approvals_claim_path(@claim), params: { remark: "ok",
      tour_claim: { claim_incidentals_attributes: { "0" => { id: @line.id, deduction_amount: 50, deduction_remark: "No bill" } } } }
    @claim.reload
    assert @claim.finance_pending?
    assert_equal 150, @claim.grand_total
    assert_equal %w[deduction_updated claim_l1_approved], @claim.activity_logs.last(2).map(&:action)
    detail = @claim.activity_logs.where(action: "deduction_updated").last.details.fetch("lines").first
    assert_includes detail.fetch("item"), "Tea"
  end

  test "invalid deduction keeps the claim where it is and shows the error" do
    sign_in @l1
    patch forward_approvals_claim_path(@claim), params: { remark: "ok",
      tour_claim: { claim_incidentals_attributes: { "0" => { id: @line.id, deduction_amount: 500, deduction_remark: "x" } } } }
    assert_response :unprocessable_entity
    assert_match "cannot exceed amount", response.body
    assert @claim.reload.submitted?
    assert_equal 0, @line.reload.deduction_amount
  end

  test "local review keeps helmet and history compact, and claims no tour sanction" do
    tour = @emp.tours.create!(tour_type: :local)
    claim = with_tasks(TourClaim.build_for(tour))
    claim.helmet_declaration = true
    claim.claim_local_travels.build(
      travel_date: tour.from_date, place_from: "HO", place_to: "Village",
      travel_mode: mode("Two Wheeler"), meter_from: 100, meter_to: 110
    )
    claim.save!
    claim.submit!(by: @emp)

    sign_in @l1
    get approvals_claim_path(claim)

    assert_response :success
    assert_match "Helmet declaration: Yes", response.body
    assert_match %(href="/tours/#{tour.id}"), response.body          # 🕒 icon opens the tour page
    assert_no_match "Balance Receivable / Payable", response.body

    get tour_path(tour)
    assert_response :success
    # A local mileage plan is not sanctioned by anyone, so its history says
    # nothing of the sort – it starts at the claim.  (The header still names
    # the tour's own stage, which is why this looks only at history rows.)
    assert_no_match(/font-medium text-slate-800">\s*Self-sanctioned/, response.body)
    assert_no_match "Tour approved", response.body
    assert_no_match "Tour sent for approval", response.body
    assert_match "Claim form prepared", response.body
  end
end
