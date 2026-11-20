require "test_helper"

# PAPL: the person filling the claim may enter Deduction Amt. / Deduction Remark on a line.
class EmployeeDeductionTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025")
    @tour = @emp.tours.create!(send_now: true, from_date: Date.current - 6, to_date: Date.current - 5,
      tour_visits_attributes: [ { visit_date: Date.current - 6, place: "Betul", planned_activity: "TOT" } ])
    @tour.approve!(by: @emp.reporting_manager, remark: "ok")
    sign_in @emp
  end

  def save_with(deduction, remark)
    post tour_claim_path(@tour), params: { commit_action: "save", tour_claim: {
      claim_incidentals_attributes: { "0" => { expense_date: @tour.from_date, particular: "Tea", amount: 200,
                                               deduction_amount: deduction, deduction_remark: remark } } } }
  end

  test "claim form has typable deduction boxes and the figures are saved" do
    get new_tour_claim_path(@tour)
    assert_match 'name="tour_claim[claim_incidentals_attributes][NEW_RECORD][deduction_amount]"', response.body
    save_with(50, "Personal share")
    line = @tour.reload.tour_claim.claim_incidentals.first
    assert_equal [ 50, "Personal share", 150 ], [ line.deduction_amount.to_i, line.deduction_remark, line.total_amount.to_i ]
  end

  test "a deduction above the amount is refused" do
    save_with(500, "Too much")
    assert_nil @tour.reload.tour_claim&.claim_incidentals&.first
  end
end
