require "test_helper"

class NotificationFlowTest < ActiveSupport::TestCase
  setup do
    @emp = user("1025"); @l1 = user("AM001"); @l2 = user("HR001"); @fin = user("FIN001"); @admin = user("ADMIN")
    @emp.update!(l2_manager: @l2)
  end

  def titles(u) = u.notifications.reload.map(&:title)

  test "tour: L1 notified on send, employee + L2 on forward, employee + L1 on final approve" do
    t = @emp.tours.create!(send_now: true, from_date: Date.current - 6, to_date: Date.current - 5,
      tour_visits_attributes: [ { visit_date: Date.current - 6, place: "Indore", planned_activity: "Mtg" } ])
    assert_equal [ "Tour for your approval (L1)" ], titles(@l1)
    t.approve!(by: @l1, remark: "ok")
    assert t.l1_approved?
    assert_includes titles(@emp), "Your tour was forwarded to L2"
    assert_includes titles(@l2), "Tour for your approval (L2)"
    t.approve!(by: @l2, remark: "fine")
    assert_includes titles(@emp), "Your tour is approved – make the claim"
    assert_includes titles(@l1), "Tour approved by L2"
    assert @emp.notifications.first.body.include?("fine")
  end

  test "tour return / reject notify employee" do
    t = @emp.tours.create!(send_now: true, from_date: Date.current + 6, to_date: Date.current + 7,
      tour_visits_attributes: [ { visit_date: Date.current + 6, place: "Indore", planned_activity: "Mtg" } ])
    t.return!(by: @l1, remark: "fix dates")
    assert_includes titles(@emp), "Your tour was returned"
    t.submit!(by: @emp)
    t.reject!(by: @l1, remark: "no")
    assert_includes titles(@emp), "Your tour was rejected"
  end

  test "claim: goes to the employee's assigned PD Finance only, everyone notified" do
    other_fin = User.create!(emp_code: "FIN002", name: "Other Finance", role: "pd_finance", password: "123456")
    @emp.update!(finance_approver: @fin)
    t = @emp.tours.create!(send_now: true, from_date: Date.current - 9, to_date: Date.current - 8,
      tour_visits_attributes: [ { visit_date: Date.current - 9, place: "Sehore", planned_activity: "Mtg" } ])
    t.approve!(by: @l1); t.approve!(by: @l2)
    c = with_tasks(TourClaim.build_for(t))
    c.claim_incidentals.build(expense_date: t.from_date, particular: "Tea", amount: 50)
    c.save!
    c.submit!(by: @emp)
    assert_equal @fin, c.finance_approver
    assert_includes titles(@l1), "Claim for your approval (L1)"
    c.forward!(by: @l1, remark: "ok")
    assert_includes titles(@l2), "Claim for your approval (L2)"
    c.forward!(by: @l2, remark: "ok")
    assert c.finance_pending?
    assert_includes titles(@fin), "Claim for final approval"
    refute_includes titles(other_fin), "Claim for final approval"
    refute c.current_reviewer?(other_fin)
    refute_includes TourClaim.in_queue_of(other_fin), c
    coding = finance_mapping(code_name: "T1")
    c.approve!(by: @fin, remark: "done", project_id: coding.project_id, budget_line_item_id: coding.budget_line_item_id,
               budget_line_item_code_id: coding.budget_line_item_code_id)
    assert_includes titles(@emp), "Your claim is approved"
    assert_includes titles(@l1), "Claim approved by PD Finance"
  end

  test "admin delete notifies employee" do
    t = @emp.tours.create!(send_now: true, from_date: Date.current + 12, to_date: Date.current + 13,
      tour_visits_attributes: [ { visit_date: Date.current + 12, place: "Indore", planned_activity: "Mtg" } ])
    t.admin_delete!(by: @admin, remark: "duplicate")
    assert_includes titles(@emp), "Your tour was deleted by admin"
  end
end
