require "csv"
require "caxlsx"

# The payment advice sheet PD Finance works with: who is to be paid, how much, into which
# account – plus the three columns they fill in and upload back (UTR No., Paid On, Remark).
#
# "Claim ID" is the key the upload matches on, so it must survive the round trip.
class PaymentAdviceExport
  HEADERS = [ "Claim ID", "Claim Type", "Emp Code", "Employee", "Location", "Period",
              "Project", "Budget Line Item", "BLI Code", "Approved On", "Grand Total", "Advance",
              "Net Payable", "Bank", "Account Holder", "Account No.", "IFSC",
              "UTR No.", "Paid On (DD/MM/YYYY)", "Payment Remark" ].freeze

  FILL_FROM = 17   # first column the uploader fills in

  def initialize(claims, period: nil)
    @claims = claims
    @period = period
  end

  def rows = @rows ||= @claims.to_a

  def to_xlsx
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Payment Advice") do |sheet|
      header = sheet.styles.add_style(b: true, bg_color: "1F8445", fg_color: "FFFFFF", alignment: { wrap_text: true })
      fill   = sheet.styles.add_style(b: true, bg_color: "FFF3C4", alignment: { wrap_text: true })
      money  = sheet.styles.add_style(format_code: "#,##0.00")
      text   = sheet.styles.add_style(format_code: "@")   # keep long UTRs and account numbers as text

      sheet.add_row HEADERS, style: Array.new(FILL_FROM, header) + Array.new(HEADERS.size - FILL_FROM, fill)
      rows.each do |claim|
        sheet.add_row row_for(claim),
          style: Array.new(10) + Array.new(3, money) + [ nil, nil, text, nil ] + Array.new(HEADERS.size - FILL_FROM, text)
      end
      add_total_row(sheet, money)
      sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen; pane.y_split = 1 }
      sheet.column_widths 10, 14, 12, 24, 16, 20, 22, 28, 14, 18, 14, 12, 14, 22, 24, 22, 14, 24, 20, 28
    end
    package.to_stream.read
  end

  def to_csv
    "﻿" + CSV.generate do |csv|
      csv << HEADERS
      rows.each { |claim| csv << row_for(claim) }
      csv << total_row if rows.any?
    end
  end

  private

  def row_for(claim)
    bank = claim.bank_account
    [ claim.id, claim.type_local? ? "Local Mileage" : "TA/DA", claim.user.emp_code, claim.user.name,
      claim.user.location&.name, claim.tour.duration_label,
      claim.project&.name, claim.budget_line_item&.name, claim.budget_line_item_code&.name,
      claim.approved_at&.strftime("%d/%m/%Y"), claim.grand_total, claim.advance_amount, claim.balance_amount,
      bank&.bank_name, bank&.account_holder_name, bank&.account_number, bank&.ifsc_code,
      claim.utr_no, claim.paid_on&.strftime("%d/%m/%Y"), claim.payment_remark ]
  end

  def total_row
    line = Array.new(HEADERS.size)
    line[0] = "TOTAL#{" (#{@period})" if @period}"
    line[1] = "#{rows.size} claim#{"s" unless rows.size == 1}"
    line[10] = rows.sum { |c| c.grand_total.to_d }
    line[11] = rows.sum { |c| c.advance_amount.to_d }
    line[12] = rows.sum { |c| c.balance_amount.to_d }
    line
  end

  def add_total_row(sheet, money)
    return if rows.empty?
    bold = sheet.styles.add_style(b: true, bg_color: "E8F2EC")
    bold_money = sheet.styles.add_style(b: true, bg_color: "E8F2EC", format_code: "#,##0.00")
    sheet.add_row total_row, style: Array.new(10, bold) + Array.new(3, bold_money) + Array.new(HEADERS.size - 13, bold)
  end
end
