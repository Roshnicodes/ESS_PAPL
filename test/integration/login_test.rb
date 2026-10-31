require "test_helper"

class LoginTest < ActionDispatch::IntegrationTest
  test "login with employee code" do
    get root_path
    assert_response :success
    get new_user_session_path
    assert_response :success
    post user_session_path, params: { user: { emp_code: "1025", password: "Password@123" } }
    assert_redirected_to root_path
    follow_redirect!
    assert_match "Priya Sharma", response.body
  end

  test "inactive employee cannot login" do
    user("1025").update!(active: false)
    post user_session_path, params: { user: { emp_code: "1025", password: "Password@123" } }
    assert_redirected_to new_user_session_path
    get root_path
    assert_match "Employee Self Service", response.body
  end
end
