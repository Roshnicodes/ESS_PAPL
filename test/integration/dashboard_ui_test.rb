require "test_helper"

class DashboardUiTest < ActionDispatch::IntegrationTest
  test "dashboard omits the removed panels and sidebar heading" do
    sign_in user("1025")

    get authenticated_root_path

    assert_response :success
    assert_no_match "dashboard-hero", response.body
    assert_no_match "Tours this year", response.body
    assert_no_match "Upcoming &amp; ongoing tours", response.body
    assert_no_match 'nav-head">My Tour', response.body
  end

  test "tour form keeps approval guidance with the selected mode, not a static list" do
    coo = User.create!(emp_code: "COOUI1", name: "Chief Operations", designation: "COO", password: "123456")
    mode = mode("Train(2A)")
    mode.set_approvers!([ coo.id ], [], [ coo.id ])
    sign_in user("1025")

    get new_tour_path

    assert_response :success
    assert_match "data-train-quota-approvals-value", response.body
    assert_match 'data-train-quota-target="approval"', response.body
    assert_no_match "also goes to", response.body
    assert_match "btn-soft-danger", response.body
    assert_match "btn-warning", response.body
    assert_match "btn-success", response.body
  end
end
