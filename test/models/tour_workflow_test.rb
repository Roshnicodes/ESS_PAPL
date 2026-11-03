require "test_helper"

class TourWorkflowTest < ActiveSupport::TestCase
  setup do
    @emp = user("1025"); @l1 = user("AM001"); @l2 = user("HR001")
    @emp.update!(l2_manager: @l2)
    @attrs = { from_date: Date.current + 5, to_date: Date.current + 6,
               tour_visits_attributes: [ { visit_date: Date.current + 5, place: "Indore", planned_activity: "Review" } ] }
  end

  test "Save keeps a draft; Save & Send goes L1 then L2" do
    t = @emp.tours.create!(@attrs)
    assert t.draft?
    assert_nil t.submitted_at
    t.submit!(by: @emp)
    assert t.submitted?
    assert_equal [ @l1, @l2 ], [ t.approver, t.l2_approver ]
    assert_raises(Workflow::NotAllowed) { t.approve!(by: @l2) }   # L2 cannot act before L1
    t.approve!(by: @l1, remark: "ok L1")
    assert t.l1_approved?
    assert_equal Tour.pending_for(@l2).to_a, [ t ]
    t.approve!(by: @l2)
    assert t.approved?
    assert_equal %w[saved_draft submitted l1_approved approved], t.activity_logs.pluck(:action)
  end

  test "tour can be planned for past months and up to the end of next month only" do
    travel_to Date.new(2026, 10, 31) do
      nov = @emp.tours.new(from_date: Date.new(2026, 11, 28), to_date: Date.new(2026, 11, 30))
      nov.valid?
      assert_not nov.errors[:base].any? { |m| m.include?("planned only till") }

      past = @emp.tours.new(from_date: Date.new(2026, 8, 3), to_date: Date.new(2026, 8, 4))
      past.valid?
      assert_not past.errors[:base].any? { |m| m.include?("planned only till") }

      dec = @emp.tours.new(from_date: Date.new(2026, 11, 30), to_date: Date.new(2026, 12, 1))
      assert_not dec.valid?
      assert_includes dec.errors[:base], "Tour can be planned only till 30/11/2026 (current and next month)"
    end
    travel_to Date.new(2026, 11, 2) { assert_equal Date.new(2026, 12, 31), Tour.latest_plan_date }
  end

  test "no L2 means L1 approval is final" do
    @emp.update!(l2_manager: nil)
    t = @emp.tours.create!(@attrs.merge(send_now: true))
    t.approve!(by: @l1)
    assert t.approved?
  end

  test "local mileage is recorded as self-sanctioned, not approved by its maker" do
    t = @emp.tours.create!(tour_type: :local)

    assert t.approved?
    assert_equal [ "self_sanctioned" ], t.activity_logs.pluck(:action)
    assert_equal @emp, t.decided_by
  end

  test "employee can cancel before claim, any stage, with remark" do
    t = @emp.tours.create!(@attrs)
    assert t.cancellable?
    t.cancel!(by: @emp, remark: "Not needed")
    assert t.cancelled?
  end

  test "planned activity is limited to 500 characters" do
    t = @emp.tours.new(@attrs.merge(tour_visits_attributes: [ { visit_date: Date.current + 5, place: "X", planned_activity: "a" * 501 } ]))
    refute t.valid?
  end

  test "place suggestions include previously typed places and cities" do
    @emp.tours.create!(@attrs)
    assert_includes TourVisit.place_suggestions, "Indore"
    assert_includes TourVisit.place_suggestions, "Jhabua"
  end

  test "claim without L2 goes L1 -> PD Finance; only current reviewer can act" do
    @emp.update!(l2_manager: nil)
    t = @emp.tours.create!(send_now: true, from_date: Date.current - 4, to_date: Date.current - 3,
      tour_visits_attributes: [ { visit_date: Date.current - 4, place: "Sehore", planned_activity: "Mtg" } ])
    t.approve!(by: @l1)
    c = with_tasks(TourClaim.build_for(t))
    c.claim_incidentals.build(expense_date: t.from_date, particular: "Tea", amount: 50)
    c.save!
    c.submit!(by: @emp)
    assert_equal @l1, c.l1_approver
    assert_nil c.l2_approver
    assert_raises(Workflow::NotAllowed) { c.forward!(by: user("FIN001")) }
    c.forward!(by: @l1)
    assert c.finance_pending?
    assert_includes TourClaim.in_queue_of(user("FIN001")), c
    admin = user("ADMIN")                                  # admin sees everything, but it is not pending with admin
    refute_includes TourClaim.in_queue_of(admin), c
    refute c.current_reviewer?(admin)
    c.approve!(by: user("FIN001"))
    assert c.approved?
  end

  test "claim Return lets the employee edit & resend; Reject is final" do
    @emp.update!(l2_manager: nil)
    t = @emp.tours.create!(send_now: true, from_date: Date.current - 4, to_date: Date.current - 3,
      tour_visits_attributes: [ { visit_date: Date.current - 4, place: "Sehore", planned_activity: "Mtg" } ])
    t.approve!(by: @l1)
    c = with_tasks(TourClaim.build_for(t))
    c.claim_incidentals.build(expense_date: t.from_date, particular: "Tea", amount: 50)
    c.save!
    c.submit!(by: @emp)
    assert_raises(Workflow::RemarkRequired) { c.return!(by: @l1, remark: "") }
    c.return!(by: @l1, remark: "Attach bill no")
    assert c.returned? && c.employee_editable?
    c.submit!(by: @emp)
    assert c.submitted?
    c.reject!(by: @l1, remark: "Duplicate claim")
    assert c.rejected?
    refute c.employee_editable?
    refute t.reload.cancellable?
  end
end
