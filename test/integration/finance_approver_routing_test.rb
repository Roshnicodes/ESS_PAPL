require "test_helper"

# Final (finance) step goes to the Finance person set on the employee in Employee List – even if that person is not PD Finance by role.
class FinanceApproverRoutingTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @l1 = user("AM001"); @pd_fin = user("FIN001")
    @fin = User.create!(emp_code: "FINX1", name: "Finance Person", role: "employee", password: "123456")
    @emp.update!(l2_manager: nil, finance_approver: nil)
    t = @emp.tours.create!(send_now: true, from_date: Date.current - 5, to_date: Date.current - 4,
      tour_visits_attributes: [ { visit_date: Date.current - 5, place: "Sehore", planned_activity: "Mtg" } ])
    t.approve!(by: @l1)
    @claim = with_tasks(TourClaim.build_for(t))
    @claim.claim_incidentals.build(expense_date: t.from_date, particular: "Tea", amount: 200)
    @claim.save!
    @claim.submit!(by: @emp)
  end

  test "claim reaches the employee's current Finance person, who can approve it" do
    @emp.update!(finance_approver: @fin)            # HR sets Finance after the claim was sent
    @claim.forward!(by: @l1, remark: "ok")
    assert_equal @fin, @claim.reload.finance_approver
    refute @claim.current_reviewer?(@pd_fin), "other PD Finance users do not get it"

    sign_in @fin
    get approvals_claims_path
    assert_match approvals_claim_path(@claim), response.body
    coding = finance_mapping
    patch approve_approvals_claim_path(@claim), params: { remark: "ok", project_id: coding.project_id,
      budget_line_item_id: coding.budget_line_item_id, budget_line_item_code_id: coding.budget_line_item_code_id }
    assert @claim.reload.approved?
    get approvals_claims_path(scope: "approved")
    assert_match approvals_claim_path(@claim), response.body
  end

  test "changing Finance in Employee List moves claims already waiting at finance" do
    @emp.update!(finance_approver: @pd_fin)
    @claim.forward!(by: @l1, remark: "ok")
    assert_equal @pd_fin, @claim.reload.finance_approver
    @emp.update!(finance_approver: @fin)
    assert_equal @fin, @claim.reload.finance_approver
  end
end
