require "test_helper"

# A travel mode with an extra approver (e.g. Flight → Director) adds an L3 step after L1 → L2.
class TourL3ApprovalTest < ActiveSupport::TestCase
  setup do
    @emp = user("1025"); @l1 = @emp.reporting_manager
    @l2 = User.create!(emp_code: "L2X1", name: "Functional Mgr", password: "123456")
    @l3 = User.create!(emp_code: "DIRX1", name: "Director X", password: "123456")
    @emp.update!(l2_manager: @l2)
    @flight = TravelMode.find_or_create_by!(name: "Flight") { |m| m.category = "public"; m.for_tour_plan = true }
    @flight.update!(for_tour_plan: true, active: true)
    @flight.set_approvers!([ @l3.id ], [])
  end

  def tour_with(mode)
    @emp.tours.create!(send_now: true, from_date: Date.current + 10, to_date: Date.current + 11,
      tour_visits_attributes: [ { visit_date: Date.current + 10, place: "Delhi", planned_activity: "Mtg", travel_mode_id: mode&.id } ])
  end

  test "flight tour goes L1 → L2 → L3 and L3 gives the final approval" do
    t = tour_with(@flight)
    assert_equal [ @l3 ], t.approval_steps.map(&:approver)
    t.approve!(by: @l1, remark: "ok")
    assert t.l1_approved?
    assert_equal @l3, t.next_approver
    t.approve!(by: @l2, remark: "ok")
    assert t.l2_approved?
    assert_includes Tour.pending_for(@l3), t
    assert_raises(Workflow::NotAllowed) { t.approve!(by: @l2, remark: "again") }
    assert_equal 1, @l3.notifications.where(kind: "tour_pending").count
    t.approve!(by: @l3, remark: "fine")
    assert t.approved?
    assert_equal @l3, t.decided_by
    assert_equal %w[submitted l1_approved l2_approved approved], t.activity_logs.map(&:action)
  end

  test "L3 can return or reject with remark" do
    t = tour_with(@flight)
    t.approve!(by: @l1, remark: "ok"); t.approve!(by: @l2, remark: "ok")
    assert_raises(Workflow::RemarkRequired) { t.return!(by: @l3, remark: "") }
    t.return!(by: @l3, remark: "Take train")
    assert t.returned?
    t.submit!(by: @emp)
    assert t.submitted? && t.l2_approved_at.nil?
    t.approve!(by: @l1, remark: "ok"); t.approve!(by: @l2, remark: "ok")
    t.reject!(by: @l3, remark: "Not needed")
    assert t.rejected?
  end

  test "Personal Four Wheeler: L1 → L2 → COO → Director, Administration only notified" do
    coo = User.create!(emp_code: "COOX1", name: "C O O", designation: "COO", password: "123456")
    admin_mgr = User.create!(emp_code: "ADMX1", name: "Admin Manager", designation: "Manager- Administration", password: "123456")
    @l3.update!(designation: "Director")
    car = TravelMode.find_or_create_by!(name: "Personal Four Wheeler") { |m| m.category = "own_vehicle" }
    car.update!(for_tour_plan: true, active: true)
    car.set_approvers!([ coo.id, @l3.id ], [ admin_mgr.id ])
    t = tour_with(car)
    assert_equal [ coo, @l3 ], t.approval_steps.map(&:approver)
    assert_equal 0, admin_mgr.notifications.count, "no notification at send"
    t.approve!(by: @l1, remark: "ok")
    t.approve!(by: @l2, remark: "ok")
    assert t.l2_approved?
    assert_equal coo, t.current_approver
    assert_equal "Director", t.next_approver_label
    assert_match "Personal Four Wheeler", coo.notifications.last.body
    t.approve!(by: coo, remark: "ok")
    assert t.reload.l2_approved?
    assert_equal @l3, t.current_approver
    assert_includes Tour.pending_for(@l3), t
    refute_includes Tour.pending_for(coo), t
    t.approve!(by: @l3, remark: "fine")
    assert t.approved?
    assert t.approval_steps.all?(&:done?)
    assert_equal 1, admin_mgr.notifications.count
    assert_match "Personal Four Wheeler", admin_mgr.notifications.last.title + admin_mgr.notifications.last.body
  end

  test "extra approver who is already L2 is skipped" do
    @flight.set_approvers!([ @l2.id, @l3.id ], [])
    t = tour_with(@flight)
    assert_equal [ @l3 ], t.approval_steps.map(&:approver)
  end

  test "tour without such a mode stays L1 → L2" do
    t = tour_with(nil)
    assert_empty t.approval_steps
    t.approve!(by: @l1, remark: "ok"); t.approve!(by: @l2, remark: "ok")
    assert t.approved?
  end

  test "no L2: L1 forwards straight to L3" do
    @emp.update!(l2_manager: nil)
    t = tour_with(@flight)
    t.approve!(by: @l1, remark: "ok")
    assert t.l2_approved?
    t.approve!(by: @l3, remark: "ok")
    assert t.approved?
  end
end

class TourMakerEditTest < ActiveSupport::TestCase
  setup do
    @emp = user("1025"); @l1 = @emp.reporting_manager
    @emp.update!(l2_manager: nil)
    @t = @emp.tours.create!(send_now: true, from_date: Date.current - 5, to_date: Date.current - 4,
      tour_visits_attributes: [ { visit_date: Date.current - 5, place: "Sehore", planned_activity: "Mtg" } ])
    @t.approve!(by: @l1, remark: "ok")
  end

  test "approved tour edited by the maker goes for approval again from L1" do
    assert @t.maker_editable?
    @t.edit_and_resend!({ general_description: "Changed plan" }, by: @emp)
    assert @t.submitted?
    assert_nil @t.approved_at
    assert_includes Tour.pending_for(@l1), @t
    assert_equal "edited_resubmitted", @t.activity_logs.last.action
  end

  test "no change keeps it approved; once a claim exists it cannot be edited" do
    @t.edit_and_resend!({ general_description: @t.general_description }, by: @emp)
    assert @t.reload.approved?
    assert_includes Tour.claim_due, @t
    with_tasks(TourClaim.build_for(@t)).save!
    refute @t.reload.maker_editable?
    refute_includes Tour.claim_due, @t
  end
end

class DaDaysTest < ActiveSupport::TestCase
  test "DA days: full 24 h = 1 day, rest ≤6 h 25 %, under 10 h 50 %, 10 h or more 100 %" do
    t0 = Time.zone.parse("2026-10-20 08:00")
    { 5 => 0.25, 6 => 0.25, 7 => 0.5, 9.5 => 0.5, 10 => 1, 11 => 1, 24 => 1, 30 => 1.25, 33 => 1.5, 34 => 2 }.each do |h, days|
      assert_equal days.to_d, ClaimDailyAllowance.days_between(t0, t0 + h.hours), "#{h} h"
    end
  end
end

class TrainApprovalTest < ActiveSupport::TestCase
  setup do
    @emp = user("1025"); @l1 = @emp.reporting_manager
    @emp.update!(l2_manager: nil)
    @coo = User.create!(emp_code: "COOT1", name: "Chief Ops", designation: "COO", password: "123456")
    @sl = TravelMode.find_or_create_by!(name: "Train(SL)") { |m| m.category = "public" }
    @ac = TravelMode.find_or_create_by!(name: "Train(3A)") { |m| m.category = "public" }
    [ @sl, @ac ].each { |m| m.update!(is_train: true, for_tour_plan: true, active: true) }
    @sl.set_approvers!([], [], [ @coo.id ])
    @ac.set_approvers!([ @coo.id ], [], [ @coo.id ])
  end

  def tour_with(mode, quota = "normal")
    @n = (@n || 0) + 3   # separate dates for every tour (no overlap)
    day = Date.current + 10 + @n
    @emp.tours.create!(send_now: true, from_date: day, to_date: day + 1,
      tour_visits_attributes: [ { visit_date: day, place: "Delhi", planned_activity: "Mtg", travel_mode_id: mode.id, ticket_quota: quota } ])
  end

  test "Train(SL) normal: L1 only; Tatkal: L1 → COO" do
    assert_empty tour_with(@sl).approval_steps
    t = tour_with(@sl, "tatkal")
    assert_equal [ @coo ], t.approval_steps.map(&:approver)
    assert_equal "Train(SL) – Tatkal", t.extra_reason
    t.approve!(by: @l1, remark: "ok")
    assert_equal @coo, t.current_approver
    t.approve!(by: @coo, remark: "ok")
    assert t.approved?
  end

  test "AC train (3A) goes to COO even on normal ticket; COO only once" do
    assert_equal [ @coo ], tour_with(@ac).approval_steps.map(&:approver)
    assert_equal [ @coo ], tour_with(@ac, "tatkal").approval_steps.map(&:approver)
  end

  test "1A goes to Director; its Tatkal booking goes to COO before Director" do
    director = User.create!(emp_code: "DIRT1", name: "Director", designation: "Director", password: "123456")
    one_ac = TravelMode.find_or_create_by!(name: "Train(1A)") { |m| m.category = "public" }
    one_ac.update!(is_train: true, for_tour_plan: true, active: true)
    one_ac.set_approvers!([ director.id ], [], [ @coo.id ])

    assert_equal [ director ], tour_with(one_ac).approval_steps.map(&:approver)
    assert_equal [ @coo, director ], tour_with(one_ac, "tatkal").approval_steps.map(&:approver)
  end

  test "Vande Bharat goes to COO" do
    vande_bharat = TravelMode.find_or_create_by!(name: "Vande Bharat Train") { |m| m.category = "public" }
    vande_bharat.update!(is_train: true, for_tour_plan: true, active: true)
    vande_bharat.set_approvers!([ @coo.id ], [], [ @coo.id ])

    assert_equal [ @coo ], tour_with(vande_bharat).approval_steps.map(&:approver)
  end

  test "Tatkal is ignored for non-train modes" do
    bus = TravelMode.find_or_create_by!(name: "Bus") { |m| m.category = "public" }
    t = tour_with(bus, "tatkal")
    assert_equal "normal", t.tour_visits.first.ticket_quota
  end
end
