require "test_helper"

class TourFormErrorsTest < ActionDispatch::IntegrationTest
  test "missing visit date: one clear error and the date box is highlighted" do
    sign_in user("1025")
    post tours_path, params: { commit_action: "save", tour: { from_date: Date.current - 2, to_date: Date.current - 1, general_description: "Work",
      tour_visits_attributes: { "0" => { visit_date: "", place: "Agra", planned_activity: "completed" } } } }
    assert_response :unprocessable_entity
    assert_equal 1, response.body.scan("Please fix the following").size
    assert_match "Visit date can&#39;t be blank", response.body
    assert_match(/class="field-error inp"[^>]*name="tour\[tour_visits_attributes\]\[0\]\[visit_date\]"/, response.body)
  end
end
