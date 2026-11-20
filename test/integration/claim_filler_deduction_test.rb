require "test_helper"

# The person filling the claim may enter Deduction Amt. / Deduction Remark on the claim form.
class ClaimFillerDeductionTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @l1 = user("AM001")
    t = @emp.tours.create!(send_now: true, from_date: Date.current - 5, to_date: Date.current - 4,
      tour_visits_attributes: [ { visit_date: Date.current - 5, place: "Sehore", planned_activity: "Mtg" } ])
    t.approve!(by: @l1)
    @claim = with_tasks(TourClaim.build_for(t))
    @claim.claim_incidentals.build(expense_date: t.from_date, particular: "Tea", amount: 200)
    @claim.save!
    @line = @claim.claim_incidentals.first
    sign_in @emp
  end

  test "the claim form has editable deduction fields" do
    get edit_tour_claim_path(@claim.tour)
    assert_response :success
    assert_match %(name="tour_claim[claim_incidentals_attributes][0][deduction_amount]"), response.body
    assert_match %(name="tour_claim[claim_incidentals_attributes][0][deduction_remark]"), response.body
  end

  test "a deduction with a remark is saved and lowers the total" do
    patch tour_claim_path(@claim.tour), params: { commit_action: "save",
      tour_claim: { claim_incidentals_attributes: { "0" => { id: @line.id, deduction_amount: 50, deduction_remark: "Personal tea" } } } }
    @line.reload
    assert_equal [ 50, "Personal tea", 150 ], [ @line.deduction_amount.to_i, @line.deduction_remark, @line.total_amount.to_i ]
  end

  test "a deduction without a remark or above the amount is refused" do
    patch tour_claim_path(@claim.tour), params: { commit_action: "save",
      tour_claim: { claim_incidentals_attributes: { "0" => { id: @line.id, deduction_amount: 50, deduction_remark: "" } } } }
    assert_equal 0, @line.reload.deduction_amount.to_i
    patch tour_claim_path(@claim.tour), params: { commit_action: "save",
      tour_claim: { claim_incidentals_attributes: { "0" => { id: @line.id, deduction_amount: 500, deduction_remark: "x" } } } }
    assert_equal 0, @line.reload.deduction_amount.to_i
  end
end
