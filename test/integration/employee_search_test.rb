require "test_helper"

class EmployeeSearchTest < ActionDispatch::IntegrationTest
  test "employee list searches designation, department, branch and manager – not only name" do
    l1 = User.create!(emp_code: "MGRS1", name: "Search Manager", password: "123456")
    User.create!(emp_code: "EMPS1", name: "Zed Person", designation: "Cluster Coordinator", department: "Watershed",
                 branch: "FCO-Jhabua", reporting_manager: l1, password: "123456")
    sign_in user("ADMIN")
    [ "Cluster Coordinator", "watershed", "jhabua", "Search Manager", "MGRS1", "coordinator jhabua" ].each do |q|
      get masters_users_path(q: q)
      assert_match "Zed Person", response.body, "searching #{q.inspect}"
    end
    get masters_users_path(q: "coordinator bhopalxyz")
    assert_no_match "Zed Person", response.body
  end
end
