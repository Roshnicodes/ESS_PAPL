require "test_helper"

# After acting, the approver returns to their pending list with a message naming the tour –
# they are never dropped straight into somebody else's tour.
class TourApprovalMessageTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @l1 = user("AM001")
    @first  = plan(Date.current + 10)
    @second = plan(Date.current + 20)
    sign_in @l1
  end

  test "approving returns to the pending list, not to the next tour" do
    patch approve_approvals_tour_path(@first), params: { remark: "Fine" }
    assert_redirected_to approvals_tours_path
    assert_match @emp.name, flash[:notice]
    assert_match @first.duration_label, flash[:notice]
    assert_match(/1 tour still pending with you/, flash[:notice])
    follow_redirect!
    assert_response :success
    assert_match @first.duration_label, response.body   # the confirmation stays on the page
  end

  test "the last approval says nothing is left" do
    [ @first, @second ].each { |t| patch approve_approvals_tour_path(t), params: { remark: "Fine" } }
    assert_match(/No tour is left for your approval/, flash[:notice])
  end

  test "return and reject also come back to the list and name the tour" do
    patch send_back_approvals_tour_path(@first), params: { remark: "Add the purpose" }
    assert_redirected_to approvals_tours_path
    assert_match "returned to #{@emp.name}", flash[:notice]

    patch reject_approvals_tour_path(@second), params: { remark: "Not required" }
    assert_redirected_to approvals_tours_path
    assert_match "rejected", flash[:notice]
    assert_match @second.duration_label, flash[:notice]
  end

  test "the tour page still offers the next pending tour as a choice" do
    get approvals_tour_path(@first)
    assert_response :success
    assert_match "Next pending", response.body
    assert_match approvals_tour_path(@second), response.body
  end

  private

  def plan(from)
    @emp.tours.create!(send_now: true, from_date: from, to_date: from + 1,
      tour_visits_attributes: [ { visit_date: from, place: "Betul", planned_activity: "Field visit" } ])
  end
end
