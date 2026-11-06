require "test_helper"

# The employee may correct a claim right up to the moment it is paid.
# Any such correction clears the approvals already given and starts again from L1.
class ClaimEditResendTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @l1 = user("AM001"); @fin = user("FIN001")
    @emp.update!(l2_manager: nil, finance_approver: @fin)
    @tour = @emp.tours.create!(send_now: true, from_date: Date.current - 4, to_date: Date.current - 3,
      tour_visits_attributes: [ { visit_date: Date.current - 4, place: "Sehore", planned_activity: "Mtg" } ])
    @tour.approve!(by: @l1)
    @claim = build_claim
  end

  # ---- while it is still with an approver ---------------------------------

  test "a claim sitting with L1 can still be corrected and goes to L1 again" do
    @claim.submit!(by: @emp)
    assert @claim.submitted?
    assert @claim.maker_editable?
    refute @claim.employee_editable?, "it is not a draft – it is already out"

    sign_in @emp
    get edit_tour_claim_path(@tour)
    assert_response :success
    assert_match "send it to L1", response.body

    patch_claim(amount: 275)
    assert_redirected_to tours_path(type: "tour")
    assert_match "sent again to L1", flash[:notice]

    @claim.reload
    assert_equal "submitted", @claim.status
    assert_equal 275, @claim.grand_total
    assert_equal @l1, @claim.l1_approver
  end

  test "a claim already approved by L1 loses that approval when corrected" do
    @claim.submit!(by: @emp)
    @claim.forward!(by: @l1, remark: "ok")
    assert @claim.finance_pending?
    assert_equal @l1, @claim.l1_approved_by

    sign_in @emp
    patch_claim(amount: 275)
    @claim.reload
    assert_equal "submitted", @claim.status
    assert_nil @claim.l1_approved_by, "the old L1 approval must not stand on changed figures"
    assert_nil @claim.l1_approved_at
    assert_nil @claim.finance_remark
  end

  # ---- after PD Finance has approved it -----------------------------------

  test "an approved claim can be corrected and goes round for approval again" do
    approve_fully
    assert @claim.approved?
    assert @claim.maker_editable?

    sign_in @emp
    patch_claim(amount: 400)
    @claim.reload
    assert_equal "submitted", @claim.status
    assert_nil @claim.approved_at
    assert_nil @claim.approved_by
    assert_equal 400, @claim.grand_total
    assert_equal "claim_edited_resubmitted", @claim.activity_logs.last.action
  end

  test "L1 and Finance are told that a claim they approved was corrected" do
    approve_fully
    sign_in @emp
    assert_difference -> { Notification.where(user: @l1).count }, 2 do   # "you had approved" + "pending with you"
      patch_claim(amount: 400)
    end
    assert Notification.where(user: @fin, kind: "claim_info").exists?
    assert Notification.where(user: @l1, kind: "claim_pending").exists?
  end

  test "correcting a claim answers the Finance question still hanging on it" do
    @claim.submit!(by: @emp)
    @claim.forward!(by: @l1, remark: "ok")
    @claim.query!(by: @fin, role: "l1", remark: "Why two teas?")
    assert @claim.finance_query?
    assert @claim.open_query.present?

    sign_in @emp
    patch_claim(amount: 275)
    @claim.reload
    assert_equal "submitted", @claim.status
    assert_nil @claim.open_query, "no question may be left hanging once the claim is rewritten"
    assert_equal "Why two teas?", @claim.claim_queries.last.question
    assert @claim.claim_queries.last.answered_at.present?
  end

  # ---- where it stops ------------------------------------------------------

  test "a paid claim can no longer be edited" do
    approve_fully
    @claim.record_payment!(utr: "SBIN0001", by: @fin)
    @claim.reload
    assert @claim.paid?
    refute @claim.maker_editable?, "the money is out – the figures are frozen"

    sign_in @emp
    get edit_tour_claim_path(@tour)
    assert_redirected_to authenticated_root_path
    patch_claim(amount: 999)
    assert_equal 150, @claim.reload.grand_total
    assert_equal "approved", @claim.status
  end

  test "a rejected claim stays final" do
    @claim.submit!(by: @emp)
    @claim.reject!(by: @l1, remark: "Duplicate")
    refute @claim.employee_editable?
    refute @claim.maker_editable?

    sign_in @emp
    patch_claim(amount: 999)
    assert_equal "rejected", @claim.reload.status
  end

  test "a cancelled claim stays untouched" do
    assert @claim.draft?
    @tour.cancel!(by: @emp, remark: "Not going")
    refute @claim.reload.maker_editable?
  end

  test "nobody else can correct somebody's claim" do
    @claim.submit!(by: @emp)
    sign_in @l1
    patch_claim(amount: 999)
    assert_equal 150, @claim.reload.grand_total
    assert_equal "submitted", @claim.status
  end

  # ---- the draft path must behave exactly as before ------------------------

  test "a draft still just saves, without being sent" do
    sign_in @emp
    patch tour_claim_path(@tour), params: { commit_action: "save", tour_claim: claim_params(100) }
    assert_match "Claim form saved", flash[:notice]
    assert_equal "draft", @claim.reload.status
    assert_nil @claim.submitted_at
  end

  test "a returned claim still edits and sends the ordinary way" do
    @claim.submit!(by: @emp)
    @claim.return!(by: @l1, remark: "Attach the bill")
    assert @claim.employee_editable?
    sign_in @emp
    patch_claim(amount: 200)
    assert_match "sent to L1", flash[:notice]
    assert_equal "submitted", @claim.reload.status
  end

  test "the history list offers Edit and Send Again once it is out" do
    @claim.submit!(by: @emp)
    sign_in @emp
    get tours_path
    assert_match "Edit &amp; Send Again", response.body
  end

  private

  def build_claim
    claim = with_tasks(TourClaim.build_for(@tour))
    claim.claim_incidentals.build(expense_date: @tour.from_date, particular: "Tea", amount: 150)
    claim.bank_account = @emp.bank_accounts.first
    claim.save!
    claim
  end

  def approve_fully
    @claim.submit!(by: @emp)
    @claim.forward!(by: @l1, remark: "ok")
    @claim.approve!(by: @fin, remark: "paid next week")   # PAPL: Finance approves without Project / BLI
  end

  def claim_params(amount)
    reports = @claim.claim_visit_reports.each_with_index.to_h do |r, i|
      [ i.to_s, { id: r.id, visit_date: r.visit_date, place_visited: r.place_visited, tasks_accomplished: r.tasks_accomplished,
                  action_points: r.action_points, time_frame: r.time_frame, remark: r.remark } ]
    end
    { bank_account_id: @claim.bank_account_id,
      claim_incidentals_attributes: { "0" => { id: @claim.claim_incidentals.first.id, expense_date: @tour.from_date,
                                               particular: "Tea", amount: amount } },
      claim_visit_reports_attributes: reports }
  end

  def patch_claim(amount:)
    patch tour_claim_path(@tour), params: { commit_action: "submit", tour_claim: claim_params(amount) }
  end
end
