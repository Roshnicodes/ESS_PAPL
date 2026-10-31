require "test_helper"

class ApprovalHistoryTest < ActionDispatch::IntegrationTest
  test "pending and acted-on tours are on separate pages" do
    emp = user("1025"); l1 = user("AM001")
    t = emp.tours.create!(send_now: true, from_date: Date.current + 400, to_date: Date.current + 401,
      tour_visits_attributes: [ { visit_date: Date.current + 400, place: "Indore", planned_activity: "Mtg" } ])
    cell = ->(body) { body.include?("href=\"/approvals/tours/#{t.id}\"") }
    sign_in l1
    get approvals_tours_path
    assert cell.(response.body)
    get done_approvals_tours_path
    refute cell.(response.body)
    patch approve_approvals_tour_path(t), params: { remark: "Looks good" }
    get approvals_tours_path
    refute cell.(response.body)
    get done_approvals_tours_path
    assert cell.(response.body)
    assert_no_match "Looks good", response.body
    assert_match "Approved", response.body
    get done_approvals_tours_path(action_type: "rejected")
    refute cell.(response.body)
  end
end
