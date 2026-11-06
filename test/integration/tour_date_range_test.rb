require "test_helper"

class TourDateRangeTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @l1 = user("AM001")
    @aug = @emp.tours.create!(from_date: Date.new(2026, 8, 3), to_date: Date.new(2026, 8, 4), send_now: true,
      tour_visits_attributes: [ { visit_date: Date.new(2026, 8, 3), place: "Indore", planned_activity: "Aug" } ])
    @dec = @emp.tours.create!(from_date: Date.current + 3, to_date: Date.current + 4, send_now: true,
      tour_visits_attributes: [ { visit_date: Date.current + 3, place: "Sehore", planned_activity: "Dec" } ])
  end

  test "pending approval and tour history filter by tour dates" do
    sign_in @l1
    get approvals_tours_path(from: "2026-08-01", to: "2026-08-31")
    assert_response :success
    assert_match approvals_tour_path(@aug), response.body
    assert_no_match approvals_tour_path(@dec), response.body
    get approvals_tours_path
    assert_match approvals_tour_path(@dec), response.body

    sign_in @emp
    get tours_path(from: "2026-08-01", to: "2026-08-31")
    assert_response :success
    assert_match %(href="#{tour_path(@aug)}"), response.body
    assert_no_match %(href="#{tour_path(@dec)}"), response.body
  end
end
