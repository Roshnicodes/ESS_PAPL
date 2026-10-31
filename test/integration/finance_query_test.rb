require "test_helper"

# Finance returns a claim to L1 / L2 with a question; they reply and it comes back to Finance.
class FinanceQueryTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @l1 = @emp.reporting_manager
    @l2 = User.create!(emp_code: "L2Q1", name: "Functional Q", password: "123456")
    @fin = User.create!(emp_code: "FINQ1", name: "Finance Q", password: "123456")
    @emp.update!(l2_manager: @l2, finance_approver: @fin)
    t = @emp.tours.create!(send_now: true, from_date: Date.current - 5, to_date: Date.current - 4,
      tour_visits_attributes: [ { visit_date: Date.current - 5, place: "Sehore", planned_activity: "Mtg" } ])
    t.approve!(by: @l1, remark: "ok"); t.approve!(by: @l2, remark: "ok")
    @claim = with_tasks(TourClaim.build_for(t))
    @claim.claim_incidentals.build(expense_date: t.from_date, particular: "Tea", amount: 200)
    @claim.save!
    @claim.submit!(by: @emp)
    @claim.forward!(by: @l1, remark: "ok"); @claim.forward!(by: @l2, remark: "ok")
  end

  test "Finance returns to L2 with remark; L2 replies; back with Finance" do
    sign_in @fin
    get approvals_claim_path(@claim)
    assert_match "L2 – #{@l2.name} (reply)", response.body
    patch send_back_approvals_claim_path(@claim), params: { return_to: "l2", remark: "Why taxi on day 1?" }
    assert @claim.reload.finance_query?
    assert_equal @l2, @claim.open_query.asked_to
    refute @claim.current_reviewer?(@fin), "Finance waits for the reply"
    assert_includes TourClaim.in_queue_of(@l2), @claim
    assert_equal 1, @l2.notifications.where(kind: "claim_query").count
    sign_out @fin

    sign_in @l2
    get approvals_claim_path(@claim)
    assert_match "Why taxi on day 1?", response.body
    patch reply_approvals_claim_path(@claim), params: { remark: "" }
    assert @claim.reload.finance_query?, "reply needs a remark"
    patch reply_approvals_claim_path(@claim), params: { remark: "No bus that day" }
    assert @claim.reload.finance_pending?
    assert_equal "No bus that day", @claim.claim_queries.last.answer
    assert @claim.current_reviewer?(@fin)
    assert_equal %w[claim_query_sent claim_query_replied], @claim.activity_logs.last(2).map(&:action)
  end

  test "Finance can still return to the employee for correction" do
    sign_in @fin
    patch send_back_approvals_claim_path(@claim), params: { return_to: "employee", remark: "Attach bill" }
    assert @claim.reload.returned?
  end

  test "someone else cannot reply" do
    @claim.query!(by: @fin, role: "l1", remark: "Check dates")
    sign_in @l2
    patch reply_approvals_claim_path(@claim), params: { remark: "x" }
    assert @claim.reload.finance_query?
  end
end

class OldMailLinkTest < ActionDispatch::IntegrationTest
  test "mail link to a tour that no longer exists shows a message instead of 404" do
    sign_in user("AM001")
    get approvals_tour_path(999_999)
    assert_redirected_to approvals_tours_path
    assert_match "not found", flash[:alert]
  end
end

class LocalMileageBadgeTest < ActionDispatch::IntegrationTest
  test "local mileage with an unsent claim shows Prepared, not Approved" do
    emp = user("1025")
    tour = emp.tours.create!(tour_type: :local)
    claim = TourClaim.build_for(tour)
    claim.claim_local_travels.build(travel_date: tour.from_date, place_from: "HO", place_to: "Bank", travel_mode: mode("Two Wheeler"), meter_from: 1, meter_to: 5)
    claim.save!
    sign_in user("ADMIN")
    get masters_all_tours_path
    row = response.body[/#{Regexp.escape(emp.name)}.*?<\/tr>/m]
    assert_match ">Prepared<", row
    assert_no_match ">Approved<", row
    get tour_path(tour)
    assert_match "Prepared (claim not sent)", response.body
  end
end
