require "test_helper"

class PasswordChangeTest < ActionDispatch::IntegrationTest
  test "employee changes own password" do
    u = user("1025")
    sign_in u
    get edit_account_password_path
    assert_response :success
    patch account_password_path, params: { user: { current_password: "wrong", password: "newpass1", password_confirmation: "newpass1" } }
    assert_response :unprocessable_entity
    patch account_password_path, params: { user: { current_password: "Password@123", password: "newpass1", password_confirmation: "newpass1" } }
    assert_redirected_to authenticated_root_path
    assert u.reload.valid_password?("newpass1")
  end
end
