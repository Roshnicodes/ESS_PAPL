require "test_helper"

# A claim / tour sent back to the employee stays visible to its L1 and L2 until it is sent again.
class ReturnedVisibleToChainTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @l1 = user("AM001"); @l2 = user("HR001")
    @emp.update!(l2_manager: @l2)
    @tour = @emp.tours.create!(send_now: true, from_date: Date.current - 5, to_date: Date.current - 4,
      tour_visits_attributes: [ { visit_date: Date.current - 5, place: "Sehore", planned_activity: "Mtg" } ])
  end

  test "a claim returned by L2 shows in the Returned tab of L1 and L2" do
    approve_tour!
    claim = with_tasks(TourClaim.build_for(@tour))
    claim.claim_incidentals.build(expense_date: @tour.from_date, particular: "Tea", amount: 200)
    claim.save!
    claim.submit!(by: @emp)
    claim.reload.forward!(by: @l1, remark: "ok")
    claim.reload.return!(by: @l2, remark: "Bill missing")

    [ @l1, @l2 ].each do |u|
      sign_in u
      get approvals_claims_path(type: "tour", scope: "returned")
      assert_response :success
      assert_match approvals_claim_path(claim), response.body, u.name
      assert_match "Returned by", response.body
    end
    sign_in @l1
    get approvals_claims_path(type: "tour")   # pending tab unchanged: nothing pending
    assert_no_match approvals_claim_path(claim), response.body
  end

  test "a claim sent again leaves the Returned tab" do
    approve_tour!
    claim = with_tasks(TourClaim.build_for(@tour))
    claim.claim_incidentals.build(expense_date: @tour.from_date, particular: "Tea", amount: 200)
    claim.save!
    claim.submit!(by: @emp)
    claim.reload.return!(by: @l1, remark: "fix")
    claim.reload.submit!(by: @emp)
    sign_in @l1
    get approvals_claims_path(type: "tour", scope: "returned")
    assert_no_match approvals_claim_path(claim), response.body
  end

  test "a tour returned by L2 shows in L1's and L2's approval history" do
    @tour.approve!(by: @l1)
    @tour.reload.return!(by: @l2, remark: "Change dates")
    [ @l1, @l2 ].each do |u|
      sign_in u
      get done_approvals_tours_path
      assert_response :success
      assert_match approvals_tour_path(@tour), response.body, u.name
    end
    sign_in @l1
    get done_approvals_tours_path(action_type: "approved")
    assert_no_match approvals_tour_path(@tour), response.body
  end

  test "a tour returned by L1 shows in L1's history too" do
    @tour.return!(by: @l1, remark: "Change dates")
    sign_in @l1
    get done_approvals_tours_path
    assert_match approvals_tour_path(@tour), response.body
  end

  private

  def approve_tour!
    @tour.approve!(by: @l1)
    @tour.reload.approve!(by: @l2) unless @tour.approved?
    @tour.reload
  end
end
