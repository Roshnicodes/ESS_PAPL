require "test_helper"

class PaymentAdviceTest < ActionDispatch::IntegrationTest
  setup do
    @fin = user("FIN001"); @emp = user("1025"); @other = user("MIS001")
    @oct = approved_claim(@emp, Date.new(2026, 10, 1), 500)
    @nov = approved_claim(@other, Date.new(2026, 11, 1), 300)
    sign_in @fin
  end

  test "the list shows approved claims with no UTR yet" do
    get payment_advices_path
    assert_response :success
    assert_match @emp.name, response.body
    assert_match @other.name, response.body
    assert_match "₹800.00", response.body   # net payable total
  end

  test "FY and month filter the list and its total" do
    get payment_advices_path(month: "2026-10")
    assert_response :success
    assert_match @emp.name, response.body
    assert_no_match(/#{@other.name}/, response.body)
    assert_match "₹500.00", response.body

    get payment_advices_path(fy: "2026-27")
    assert_match "₹800.00", response.body
  end

  test "one UTR is recorded on several ticked claims at once" do
    patch record_payment_advices_path, params: { claim_ids: [ @oct.id, @nov.id ], utr_no: "sbin/2026/0099",
                                                 paid_on: "2026-11-05", payment_remark: "NEFT batch 7" }
    assert_redirected_to payment_advices_path
    assert_match "recorded on 2 claims", flash[:notice]
    [ @oct, @nov ].each do |c|
      c.reload
      assert_equal "SBIN/2026/0099", c.utr_no
      assert_equal Date.new(2026, 11, 5), c.paid_on
      assert_equal "NEFT batch 7", c.payment_remark
      assert_equal @fin, c.utr_updated_by
      assert c.paid?
    end
  end

  test "a single row saves only its own claim" do
    patch record_payment_advices_path, params: { claim_ids: [ @oct.id ], utr_no: "HDFC001122" }
    assert @oct.reload.paid?
    assert_equal "HDFC001122", @oct.utr_no
    refute @nov.reload.paid?
    assert_equal Date.current, @oct.paid_on
  end

  test "paid claims leave the pending list and appear under Paid" do
    patch record_payment_advices_path, params: { claim_ids: [ @oct.id ], utr_no: "HDFC001122" }
    get payment_advices_path
    assert_no_match(/#{@emp.name}/, response.body)
    get payment_advices_path(scope: "paid")
    assert_match @emp.name, response.body
    assert_match "HDFC001122", response.body
  end

  test "the employee is told the payment was made" do
    assert_difference -> { Notification.where(user: @emp, kind: "claim_paid").count }, 1 do
      patch record_payment_advices_path, params: { claim_ids: [ @oct.id ], utr_no: "HDFC001122" }
    end
    assert_match "HDFC001122", Notification.where(user: @emp, kind: "claim_paid").last.body
  end

  test "a blank UTR or nothing ticked is refused" do
    patch record_payment_advices_path, params: { claim_ids: [ @oct.id ], utr_no: "  " }
    assert_match "Type the UTR", flash[:alert]
    patch record_payment_advices_path, params: { utr_no: "ABC123" }
    assert_match "Tick at least one claim", flash[:alert]
    refute @oct.reload.paid?
  end

  test "a UTR cannot be put on a claim that is not approved" do
    pending = TourClaim.find(@oct.id)
    pending.update_columns(status: "finance_pending")
    patch record_payment_advices_path, params: { claim_ids: [ pending.id ], utr_no: "ABC123" }
    assert_match "no longer approved", flash[:alert]
    assert_nil pending.reload.utr_no
  end

  test "an employee with no Finance duty cannot open it" do
    sign_in @emp
    get payment_advices_path
    assert_redirected_to authenticated_root_path
    patch record_payment_advices_path, params: { claim_ids: [ @oct.id ], utr_no: "ABC123" }
    assert_nil @oct.reload.utr_no

    sign_in user("ADMIN")
    get payment_advices_path
    assert_response :success
  end

  test "the menu shows Payment Advice to Finance only, and Leave to everybody" do
    get authenticated_root_path
    assert_match "Payment Advice", response.body
    assert_match "app.hrone.cloud/app/request/initiate-leave", response.body

    sign_in @emp
    get authenticated_root_path
    assert_no_match(/Payment Advice/, response.body)
    assert_match "app.hrone.cloud/app/request/initiate-leave", response.body
  end

  # Swapnil Amne in the live system: role "Employee", but HR made him the Finance person
  # for a whole branch, so every claim of those employees ends with him.
  test "a named Finance approver gets the menu and only their own employees' claims" do
    named = user("AM001")
    assert_equal "employee", named.role
    # HR sets him as the Finance person on the employee (Employee master → Finance);
    # that employee's claims then carry him as their finance approver.
    @emp.update_columns(finance_approver_id: named.id)
    @oct.update_columns(finance_approver_id: named.id)

    sign_in named
    get authenticated_root_path
    assert_match "Payment Advice", response.body

    get payment_advices_path
    assert_response :success
    assert_match @emp.name, response.body            # the employee they are Finance for
    assert_no_match(/#{@other.name}/, response.body) # somebody else's – not theirs to pay

    patch record_payment_advices_path, params: { claim_ids: [ @oct.id, @nov.id ], utr_no: "AXIS0099" }
    assert_equal "AXIS0099", @oct.reload.utr_no
    assert_nil @nov.reload.utr_no, "a claim they are not the Finance person for must stay untouched"
  end

  test "someone who is nobody's Finance person still cannot open it" do
    sign_in @other
    get authenticated_root_path
    assert_no_match(/Payment Advice/, response.body)
    get payment_advices_path
    assert_redirected_to authenticated_root_path
  end

  test "the Excel download carries the filter and the fill-in columns" do
    get payment_advices_path(month: "2026-10", format: :csv)
    assert_response :success
    head, row, total = response.body.lines
    assert_match "UTR No.", head
    assert_match "Claim ID", head
    assert_match @emp.emp_code, row
    assert_match "TOTAL (Oct-2026)", total
    get payment_advices_path(month: "2026-10", format: :xlsx)
    assert_match "payment_advice_pending_2026-27_oct", response.headers["Content-Disposition"]
  end

  private

  def approved_claim(employee, month, amount)
    tour = Tour.new(user: employee, tour_type: "local", general_description: "local travel milage claim")
    tour.save!
    tour.update_columns(claim_month: month, from_date: month, to_date: month.end_of_month)
    claim = TourClaim.build_for(tour.reload)
    claim.claim_local_travels.build(travel_date: month, place_from: "Office", place_to: "Field",
                                    travel_mode: mode("Public Transport"), kilometers: 10, amount: amount, purpose: "Visit")
    claim.bank_account = employee.bank_accounts.first
    claim.save!
    coding = finance_mapping
    claim.update_columns(status: "approved", approved_at: Time.current, approved_by_id: @fin.id,
                         project_id: coding.project_id, budget_line_item_id: coding.budget_line_item_id,
                         budget_line_item_code_id: coding.budget_line_item_code_id,
                         l1_approver_id: user("AM001").id, finance_approver_id: @fin.id)
    claim.reload
  end
end
