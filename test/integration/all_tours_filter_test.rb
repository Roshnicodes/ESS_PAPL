require "test_helper"

class AllToursFilterTest < ActionDispatch::IntegrationTest
  setup do
    @admin = user("ADMIN"); @emp = user("1025"); @l1 = user("AM001")
    @old = @emp.tours.create!(from_date: Date.new(2026, 8, 3), to_date: Date.new(2026, 8, 4), send_now: true,
      tour_visits_attributes: [ { visit_date: Date.new(2026, 8, 3), place: "Indore", planned_activity: "Old visit" } ])
    @old.update_columns(status: "approved", approved_at: Time.current, decided_by_id: @l1.id, created_at: 2.months.ago)
    @pending = @emp.tours.create!(from_date: Date.current + 3, to_date: Date.current + 4, send_now: true,
      tour_visits_attributes: [ { visit_date: Date.current + 3, place: "Sehore", planned_activity: "New visit" } ])
    @draft = @emp.tours.create!(from_date: Date.current + 10, to_date: Date.current + 11,
      tour_visits_attributes: [ { visit_date: Date.current + 10, place: "Ashta", planned_activity: "Saved only" } ])
    sign_in @admin
  end

  def ids = response.body.scan(%r{href="/tours/(\d+)/edit"}).flatten.map(&:to_i).uniq

  test "pending first by default (PAPL); latest, oldest-first and tour-date sorts work" do
    get masters_all_tours_path
    assert_response :success
    assert_equal @pending.id, (ids & [ @old.id, @pending.id, @draft.id ]).first
    assert ids.index(@old.id) < ids.index(@draft.id)                    # merely saved ones last
    get masters_all_tours_path(sort: "newest")
    assert ids.index(@draft.id) < ids.index(@old.id)
    get masters_all_tours_path(sort: "oldest")
    assert ids.index(@old.id) < ids.index(@draft.id)
    get masters_all_tours_path(sort: "tour_date_desc")
    assert ids.index(@draft.id) < ids.index(@pending.id)
    get masters_all_tours_path(sort: "pending_first")
    assert_equal @pending.id, (ids & [ @old.id, @pending.id, @draft.id ]).first
  end

  test "stage and date filters" do
    get masters_all_tours_path(stage: "pending")
    assert_includes ids, @pending.id
    assert_not_includes ids, @old.id
    assert_not_includes ids, @draft.id

    get masters_all_tours_path(stage: "prepared")
    assert_includes ids, @draft.id
    assert_not_includes ids, @pending.id

    get masters_all_tours_path(from: "2026-08-01", to: "2026-08-31")
    assert_equal [ @old.id ], ids & [ @old.id, @pending.id, @draft.id ]
  end
end
