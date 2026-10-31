require "test_helper"

class TourMakerEditFlowTest < ActionDispatch::IntegrationTest
  test "Edit button on an approved tour; saving sends it to L1 again" do
    emp = user("1025"); l1 = emp.reporting_manager
    emp.update!(l2_manager: nil)
    t = emp.tours.create!(send_now: true, from_date: Date.current + 5, to_date: Date.current + 6,
      tour_visits_attributes: [ { visit_date: Date.current + 5, place: "Sehore", planned_activity: "Mtg" } ])
    t.approve!(by: l1, remark: "ok")
    sign_in emp
    get tours_path
    assert_match edit_tour_path(t), response.body
    get edit_tour_path(t)
    assert_response :success
    assert_match "Save &amp; Send Again", response.body
    patch tour_path(t), params: { commit_action: "send", tour: { general_description: "New purpose" } }
    assert_redirected_to tour_path(t)
    assert t.reload.submitted?
    assert_equal "New purpose", t.general_description
  end
end
