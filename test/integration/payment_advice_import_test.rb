require "test_helper"

# Download the payment advice, fill the UTR column, upload it back.
class PaymentAdviceImportTest < ActionDispatch::IntegrationTest
  setup do
    @fin = user("FIN001"); @emp = user("1025"); @other = user("MIS001")
    @a = approved_claim(@emp, Date.new(2026, 10, 1), 500)
    @b = approved_claim(@other, Date.new(2026, 10, 1), 300)
    sign_in @fin
  end

  test "a filled sheet records the UTRs in bulk and leaves blank rows alone" do
    file = csv_file([ [ @a.id, "SBIN/2026/1", "05/11/2026", "NEFT batch" ], [ @b.id, "", "", "" ] ])
    post import_payment_advices_path, params: { file: file }
    assert_redirected_to payment_advices_path
    assert_match "1 UTR recorded", flash[:notice]
    assert_equal "SBIN/2026/1", @a.reload.utr_no
    assert_equal Date.new(2026, 11, 5), @a.paid_on
    assert_equal "NEFT batch", @a.payment_remark
    assert_nil @b.reload.utr_no, "a blank UTR must never clear or set anything"
  end

  test "the same UTR again counts as unchanged, a different one as a correction" do
    post import_payment_advices_path, params: { file: csv_file([ [ @a.id, "UTR001", "", "" ] ]) }
    assert_match "1 UTR recorded", flash[:notice]

    post import_payment_advices_path, params: { file: csv_file([ [ @a.id, "utr001", "", "" ] ]) }
    assert_match "1 already the same", flash[:notice]

    post import_payment_advices_path, params: { file: csv_file([ [ @a.id, "UTR002", "", "" ] ]) }
    assert_match "1 corrected", flash[:notice]
    assert_equal "UTR002", @a.reload.utr_no
  end

  test "unknown and non-approved rows are reported, the good ones still go through" do
    @b.update_columns(status: "finance_pending")
    post import_payment_advices_path, params: { file: csv_file([ [ @a.id, "UTR001", "", "" ], [ @b.id, "UTR002", "", "" ], [ 999_999, "UTR003", "", "" ] ]) }
    assert_match "1 UTR recorded", flash[:notice]
    assert_match "2 skipped", flash[:notice]
    assert_equal 2, flash[:import_errors].size
    assert_equal "UTR001", @a.reload.utr_no
    assert_nil @b.reload.utr_no
  end

  test "a round trip through the real CSV download works" do
    get payment_advices_path(month: "2026-10", format: :csv)
    rows = CSV.parse(response.body)
    utr_at = rows.first.index("UTR No.")
    rows[1..].each { |r| r[utr_at] = "RT#{r[0]}" unless r[0].to_s.start_with?("TOTAL") }

    post import_payment_advices_path, params: { file: upload(CSV.generate { |c| rows.each { |r| c << r } }) }
    assert_match "2 UTR recorded", flash[:notice]
    assert_equal "RT#{@a.id}", @a.reload.utr_no
    assert_equal "RT#{@b.id}", @b.reload.utr_no
  end

  test "a round trip through the real Excel download works" do
    get payment_advices_path(month: "2026-10", format: :xlsx)
    path = Rails.root.join("tmp", "pa_#{SecureRandom.hex(4)}.xlsx")
    File.binwrite(path, response.body)

    # read the real download back, fill the UTR column, write it out again as .xlsx
    sheet = Roo::Spreadsheet.open(path.to_s, extension: :xlsx).sheet(0)
    header = sheet.row(1)
    utr_at = header.index("UTR No.")
    assert utr_at, "the download must carry a UTR No. column"
    body = (2..sheet.last_row).map do |r|
      row = sheet.row(r)
      row[utr_at] = "XL#{row[0].to_i}" unless row[0].to_s.start_with?("TOTAL")
      row
    end

    out = Rails.root.join("tmp", "pa_filled_#{SecureRandom.hex(4)}.xlsx")
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Payment Advice") do |ws|
      ws.add_row header
      body.each { |row| ws.add_row row }
    end
    package.serialize(out.to_s)

    post import_payment_advices_path, params: { file: Rack::Test::UploadedFile.new(out, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") }
    assert_match "2 UTR recorded", flash[:notice]
    assert_equal "XL#{@a.id}", @a.reload.utr_no
    assert_equal "XL#{@b.id}", @b.reload.utr_no
  end

  test "a file without a UTR column is refused" do
    post import_payment_advices_path, params: { file: upload("Name,Amount\nFoo,10\n") }
    assert_match "Could not read the file", flash[:alert]
  end

  test "an employee cannot upload" do
    sign_in @emp
    post import_payment_advices_path, params: { file: csv_file([ [ @a.id, "UTR001", "", "" ] ]) }
    assert_nil @a.reload.utr_no
  end

  private

  def csv_file(rows)
    body = CSV.generate do |csv|
      csv << [ "Claim ID", "Emp Code", "UTR No.", "Paid On (DD/MM/YYYY)", "Payment Remark" ]
      rows.each { |id, utr, paid, remark| csv << [ id, "", utr, paid, remark ] }
    end
    upload(body)
  end

  def upload(body)
    path = Rails.root.join("tmp", "pa_#{SecureRandom.hex(4)}.csv")
    File.write(path, body)
    Rack::Test::UploadedFile.new(path, "text/csv")
  end

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
