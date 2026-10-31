require "test_helper"

class BankAccountsTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @l1 = user("AM001")
    @fin = User.create!(emp_code: "FINB1", name: "Finance B", role: "employee", password: "123456")
    @emp.update!(l2_manager: nil, finance_approver: @fin)
    @passbook = fixture_file_upload("passbook.png", "image/png")
  end

  def make_claim(bank: :default)
    t = @emp.tours.create!(send_now: true, from_date: Date.current - 5, to_date: Date.current - 4,
      tour_visits_attributes: [ { visit_date: Date.current - 5, place: "Sehore", planned_activity: "Mtg" } ])
    t.approve!(by: @l1)
    c = with_tasks(TourClaim.build_for(t))
    c.bank_account = nil if bank.nil?
    c.claim_incidentals.build(expense_date: t.from_date, particular: "Tea", amount: 200)
    c.save!
    c
  end

  test "employee adds a second account with passbook; number must match and IFSC be valid" do
    sign_in @emp
    get account_bank_accounts_path
    assert_response :success
    post account_bank_accounts_path, params: { bank_account: { account_holder_name: "Emp", bank_name: "HDFC Bank", account_number: "50100123456789",
      account_number_confirmation: "50100123456780", ifsc_code: "hdfc0000123", passbook: @passbook } }
    assert_response :unprocessable_entity
    post account_bank_accounts_path, params: { bank_account: { account_holder_name: "Emp", bank_name: "HDFC Bank", account_number: "50100123456789",
      account_number_confirmation: "50100123456789", ifsc_code: "hdfc0000123", passbook: @passbook } }
    a = @emp.bank_accounts.find_by!(account_number: "50100123456789")
    assert_equal "HDFC0000123", a.ifsc_code
    assert a.passbook.attached?
    refute a.primary?, "first account stays primary"
    assert_equal "bank_added", a.activity_logs.last.action
  end

  test "employee can deactivate and activate again; inactive one is not offered and is cleared from drafts" do
    a = @emp.bank_accounts.first
    c = make_claim
    assert_equal a, c.bank_account
    sign_in @emp
    patch toggle_account_bank_account_path(a)
    refute a.reload.active?
    assert_nil c.reload.bank_account_id
    get edit_tour_claim_path(c.tour)
    assert_no_match %(<option value="#{a.id}"), response.body
    assert_match "No active bank account", response.body
    patch toggle_account_bank_account_path(a)
    assert a.reload.active?
    assert a.primary?
  end

  test "claim cannot be sent without a bank account" do
    c = make_claim(bank: nil)
    assert_raises(ActiveRecord::RecordInvalid) { c.submit!(by: @emp) }
    assert c.reload.draft?
  end

  test "only the claim's Finance person sees the bank details and passbook" do
    c = make_claim
    c.submit!(by: @emp)
    a = c.bank_account
    sign_in @l1
    get approvals_claim_path(c)
    assert_no_match a.account_number, response.body
    get passbook_account_bank_account_path(a)
    assert_redirected_to authenticated_root_path
    c.forward!(by: @l1, remark: "ok")

    sign_in @fin
    get approvals_claim_path(c)
    assert_match a.account_number, response.body
    get passbook_account_bank_account_path(a)
    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "account used on a sent claim is locked" do
    c = make_claim
    c.submit!(by: @emp)
    a = c.bank_account
    refute a.update(account_number: "999999999")
    assert a.reload.update(branch_name: "Bhopal")
  end

  test "bank is selected on the claim form, not on the Tour Plan" do
    second = bank_account_for(@emp, number: "77700011122")
    sign_in @emp
    get new_tour_path
    assert_no_match "Payment Bank Account", response.body
    post tours_path, params: { commit_action: "send", tour: { from_date: Date.current - 5, to_date: Date.current - 4, bank_account_id: second.id,
      tour_visits_attributes: { "0" => { visit_date: Date.current - 5, place: "Sehore", planned_activity: "Mtg" } } } }
    tour = @emp.tours.order(:id).last
    assert_nil tour.bank_account
    tour.approve!(by: @l1)
    assert_equal @emp.bank_accounts.usable.ordered.first, with_tasks(TourClaim.build_for(tour)).bank_account
  end

  test "local mileage form has the bank dropdown" do
    sign_in @emp
    get new_local_mileage_path
    assert_match "Payment Bank Account", response.body
  end
end
