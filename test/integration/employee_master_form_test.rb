require "test_helper"

class EmployeeMasterFormTest < ActionDispatch::IntegrationTest
  setup { sign_in user("ADMIN") }

  test "managers read L-1 then L-2, with Finance after them" do
    get new_masters_user_path
    assert_response :success
    b = response.body
    assert b.index("user_reporting_manager_id") < b.index("user_l2_manager_id"), "L-1 must come first"
    assert b.index("user_l2_manager_id") < b.index("user_finance_approver_id"), "L-2 must sit between L-1 and Finance"
  end

  test "the password boxes have a show / hide toggle" do
    get edit_masters_user_path(user("1025"))
    assert_response :success
    assert_equal 2, response.body.scan('data-controller="reveal"').size
    assert_equal 2, response.body.scan("reveal#toggle").size
    assert_match "The old password cannot be shown", response.body
  end

  test "an admin can still set a password from this form" do
    emp = user("1025")
    patch masters_user_path(emp), params: { user: { emp_code: emp.emp_code, name: emp.name, password: "newpass", password_confirmation: "newpass" } }
    assert_redirected_to masters_users_path
    assert emp.reload.valid_password?("newpass")
  end
end
