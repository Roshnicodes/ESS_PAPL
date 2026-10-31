require "test_helper"

# TA/DA claim follows the same extra rules as the tour plan: L1 → L2 → COO → Director → Finance.
class ClaimExtraApprovalTest < ActiveSupport::TestCase
  setup do
    @emp = user("1025"); @l1 = @emp.reporting_manager
    @l2  = User.create!(emp_code: "L2C1", name: "Functional C", password: "123456")
    @coo = User.create!(emp_code: "COOC1", name: "Chief Ops C", designation: "COO", password: "123456")
    @dir = User.create!(emp_code: "DIRC1", name: "Director C", designation: "Director", password: "123456")
    @fin = User.create!(emp_code: "FINC1", name: "Finance C", password: "123456")
    @emp.update!(l2_manager: @l2, finance_approver: @fin)
    @car = TravelMode.find_or_create_by!(name: "Personal Four Wheeler") { |m| m.category = "own_vehicle" }
    @car.update!(for_tour_plan: true, active: true)
    @car.set_approvers!([ @coo.id, @dir.id ], [])
    @bus = TravelMode.find_or_create_by!(name: "Bus") { |m| m.category = "public" }
  end

  def claim_for(mode)
    t = @emp.tours.create!(send_now: true, from_date: Date.current - 5, to_date: Date.current - 4,
      tour_visits_attributes: [ { visit_date: Date.current - 5, place: "Sehore", planned_activity: "Mtg", travel_mode_id: mode.id } ])
    t.approve!(by: @l1, remark: "ok"); t.approve!(by: @l2, remark: "ok")
    t.approval_steps.each { |s| t.approve!(by: s.approver, remark: "ok") }
    c = with_tasks(TourClaim.build_for(t))
    c.claim_incidentals.build(expense_date: t.from_date, particular: "Tea", amount: 200)
    c.save!
    c.submit!(by: @emp)
    c
  end

  test "four-wheeler claim: L1 → L2 → COO → Director → Finance" do
    c = claim_for(@car)
    assert_equal [ @coo, @dir ], c.approval_steps.map(&:approver)
    c.forward!(by: @l1, remark: "ok")
    c.forward!(by: @l2, remark: "ok")
    assert c.extra_pending?
    assert_equal @coo, c.extra_approver
    assert_includes TourClaim.in_queue_of(@coo), c
    assert_equal "Director", c.next_reviewer_label
    assert_raises(Workflow::NotAllowed) { c.forward!(by: @dir, remark: "early") }
    c.forward!(by: @coo, remark: "ok")
    assert_equal @dir, c.reload.extra_approver
    c.forward!(by: @dir, remark: "ok")
    assert c.reload.finance_pending?
    assert c.current_reviewer?(@fin)
    assert c.approval_steps.all?(&:done?)
  end

  test "extra approver can return the claim with remark" do
    c = claim_for(@car)
    c.forward!(by: @l1, remark: "ok"); c.forward!(by: @l2, remark: "ok")
    c.return!(by: @coo, remark: "Why car?")
    assert c.reload.returned?
  end

  test "bus claim goes L1 → L2 → Finance (no extra steps)" do
    c = claim_for(@bus)
    assert_empty c.approval_steps
    c.forward!(by: @l1, remark: "ok"); c.forward!(by: @l2, remark: "ok")
    assert c.reload.finance_pending?
  end
end

class ClaimExtraApprovalPageTest < ActionDispatch::IntegrationTest
  test "COO sees the claim in TA/DA Recommendation and forwards it to Director" do
    emp = user("1025"); l1 = emp.reporting_manager
    coo = User.create!(emp_code: "COOP1", name: "Chief Ops P", designation: "COO", password: "123456")
    dir = User.create!(emp_code: "DIRP1", name: "Director P", designation: "Director", password: "123456")
    emp.update!(l2_manager: nil)
    car = TravelMode.find_or_create_by!(name: "Personal Four Wheeler") { |m| m.category = "own_vehicle" }
    car.update!(for_tour_plan: true, active: true)
    car.set_approvers!([ coo.id, dir.id ], [])
    t = emp.tours.create!(send_now: true, from_date: Date.current - 5, to_date: Date.current - 4,
      tour_visits_attributes: [ { visit_date: Date.current - 5, place: "Sehore", planned_activity: "Mtg", travel_mode_id: car.id } ])
    t.approve!(by: l1, remark: "ok"); t.approve!(by: coo, remark: "ok"); t.approve!(by: dir, remark: "ok")
    c = with_tasks(TourClaim.build_for(t)); c.claim_incidentals.build(expense_date: t.from_date, particular: "Tea", amount: 200); c.save!
    c.submit!(by: emp)
    c.forward!(by: l1, remark: "ok")

    sign_in coo
    get approvals_claims_path
    assert_match approvals_claim_path(c), response.body
    get approvals_claim_path(c)
    assert_match "Forward to Director", response.body
    assert_match "Personal Four Wheeler", response.body
    patch forward_approvals_claim_path(c), params: { remark: "ok" }
    assert_equal dir, c.reload.extra_approver
  end
end

class LocalMileageExtraApprovalTest < ActiveSupport::TestCase
  test "local mileage with Four Wheeler: L1 → COO → Director → Finance; Administration notified on approval" do
    emp = user("1025"); l1 = emp.reporting_manager
    emp.update!(l2_manager: nil, finance_approver: nil)
    coo = User.create!(emp_code: "COOL1", name: "Chief Ops L", designation: "COO", password: "123456")
    dir = User.create!(emp_code: "DIRL1", name: "Director L", designation: "Director", password: "123456")
    adm = User.create!(emp_code: "ADML1", name: "Admin Mgr L", designation: "Manager- Administration", password: "123456")
    car = mode("Four Wheeler")
    car.set_approvers!([ coo.id, dir.id ], [ adm.id ])
    tour = emp.tours.create!(tour_type: :local)
    c = TourClaim.build_for(tour)
    c.claim_local_travels.build(travel_date: tour.from_date, place_from: "HO", place_to: "Bank", travel_mode: car, meter_from: 100, meter_to: 120)
    c.save!
    c.submit!(by: emp)
    assert_equal [ coo, dir ], c.approval_steps.map(&:approver)
    c.forward!(by: l1, remark: "ok")
    assert_equal coo, c.extra_approver
    c.forward!(by: coo, remark: "ok")
    c.forward!(by: dir, remark: "ok")
    assert c.reload.finance_pending?
    coding = finance_mapping
    c.approve!(by: user("FIN001"), remark: "ok", project_id: coding.project_id,
               budget_line_item_id: coding.budget_line_item_id, budget_line_item_code_id: coding.budget_line_item_code_id)
    assert c.approved?
    assert_equal 1, adm.notifications.where(kind: "claim_info").count
  end
end

class ClaimTatkalTest < ActiveSupport::TestCase
  test "A. Travel train on Tatkal adds the COO step; Normal does not; non-train is always Normal" do
    emp = user("1025"); l1 = emp.reporting_manager
    emp.update!(l2_manager: nil)
    coo = User.create!(emp_code: "COOT9", name: "Chief Ops T", designation: "COO", password: "123456")
    sl = TravelMode.find_or_create_by!(name: "Train(SL)") { |m| m.category = "public" }
    sl.update!(is_train: true, for_city_travel: true, active: true)
    sl.set_approvers!([], [], [ coo.id ])
    bus = TravelMode.find_or_create_by!(name: "Bus") { |m| m.category = "public" }
    t = emp.tours.create!(send_now: true, from_date: Date.current - 5, to_date: Date.current - 4,
      tour_visits_attributes: [ { visit_date: Date.current - 5, place: "Sehore", planned_activity: "Mtg", travel_mode_id: bus.id } ])
    t.approve!(by: l1, remark: "ok")

    c = with_tasks(TourClaim.build_for(t))
    c.claim_city_travels.build(travel_date: t.from_date, departure_city: "Bhopal", arrival_city: "Delhi", travel_mode: sl, ticket_quota: "normal", amount: 500)
    c.save!
    c.submit!(by: emp)
    assert_empty c.approval_steps, "Normal ticket – no extra step"
    c.return!(by: l1, remark: "fix")

    c.claim_city_travels.first.update!(ticket_quota: "tatkal")
    c.reload.submit!(by: emp)
    assert_equal [ coo ], c.approval_steps.map(&:approver)
    assert_equal "Train(SL) – Tatkal", c.extra_reason

    row = c.claim_city_travels.build(travel_date: t.from_date, departure_city: "A", arrival_city: "B", travel_mode: bus, ticket_quota: "tatkal", amount: 10)
    row.valid?
    assert_equal "normal", row.ticket_quota
  end
end
