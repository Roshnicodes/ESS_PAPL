require "test_helper"

class NotificationsTest < ActionDispatch::IntegrationTest
  test "bell shows unread, opening marks read and redirects" do
    emp = user("1025"); l1 = user("AM001")
    emp.tours.create!(send_now: true, from_date: Date.current + 3, to_date: Date.current + 4,
      tour_visits_attributes: [ { visit_date: Date.current + 3, place: "Indore", planned_activity: "Mtg" } ])
    n = l1.notifications.first
    sign_in l1
    get authenticated_root_path
    assert_match "Tour for your approval (L1)", response.body
    get notification_path(n)
    assert_redirected_to approvals_tour_path(n.notifiable)
    assert n.reload.read?
    get notifications_path
    assert_response :success
  end
end

class TourHistoryBadgeTest < ActionDispatch::IntegrationTest
  test "tour history shows red badge per tour; opening the tour page marks them read" do
    emp = user("1025"); l1 = user("AM001")
    t = emp.tours.create!(send_now: true, from_date: Date.current + 3, to_date: Date.current + 4,
      tour_visits_attributes: [ { visit_date: Date.current + 3, place: "Indore", planned_activity: "Mtg" } ])
    t.return!(by: l1, remark: "fix")
    sign_in emp
    get tours_path
    assert_match "data-badge", response.body
    assert_no_match ">Notifications<", response.body.scan(/<nav.*?<\/nav>/m).join  # no separate menu
    get tour_path(t)                                                  # History icon opens the tour page
    assert_match "Tour returned to employee", response.body
    assert_equal 0, emp.notifications.unread.count
  end
end
