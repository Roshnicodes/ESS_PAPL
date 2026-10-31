require "test_helper"

class AdminTourTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @am = user("AM001"); @admin = user("ADMIN")
    @tour = @emp.tours.create!(send_now: true, from_date: Date.current + 2, to_date: Date.current + 3,
      tour_visits_attributes: [ { visit_date: Date.current + 2, place: "Indore", planned_activity: "Mtg" } ])
    @tour.approve!(by: @am)
  end

  test "admin edits an approved tour; change is logged; status unchanged" do
    sign_in @admin
    get masters_all_tours_path
    assert_response :success
    assert_match "Tour Plan", response.body
    assert_no_match @tour.reference_no, response.body
    get edit_tour_path(@tour)
    assert_response :success
    assert_match "Admin edit", response.body
    patch tour_path(@tour), params: { admin_remark: "Typo", tour: { general_description: "Corrected by admin" } }
    assert_redirected_to tour_path(@tour)
    @tour.reload
    assert @tour.approved?
    assert_equal "Corrected by admin", @tour.general_description
    log = @tour.activity_logs.last
    assert_equal [ "admin_edited", "Typo" ], [ log.action, log.remark ]
  end

  test "admin deletes with remark (soft delete, audit kept); employees cannot" do
    sign_in @emp
    delete tour_path(@tour), params: { delete_remark: "x" }
    assert Tour.exists?(@tour.id)
    sign_out @emp

    sign_in @admin
    delete tour_path(@tour), params: { delete_remark: "" }
    assert Tour.exists?(@tour.id), "remark required"
    delete tour_path(@tour), params: { delete_remark: "Duplicate entry" }
    assert_redirected_to masters_all_tours_path
    refute Tour.exists?(@tour.id)
    t = Tour.with_deleted.find(@tour.id)
    assert_equal [ @admin.id, "Duplicate entry" ], [ t.deleted_by_id, t.delete_remark ]
    assert_equal "deleted", ActivityLog.where(trackable_type: "Tour", trackable_id: t.id).last.action
    # dates are free again for a new tour
    @emp.tours.create!(send_now: true, from_date: t.from_date, to_date: t.to_date,
      tour_visits_attributes: [ { visit_date: t.from_date, place: "Indore", planned_activity: "Mtg" } ])
  end

  test "back button shows on inner pages" do
    sign_in @emp
    get tours_path
    assert_match "history.back()", response.body
  end
end
