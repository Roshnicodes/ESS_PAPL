require "csv"
require "caxlsx"

# Downloadable claim report for Excel, with CSV retained for callers that
# already use the older endpoint.
class ClaimExport
  HEADERS = [ "Claim Type", "Emp Code", "Employee", "Location", "Tour Duration", "Status", "Receiving Date",
              "A. Travel", "B. Local", "C. Lodging", "D. DA", "E. Incidental", "Grand Total", "Advance", "Balance",
              "L1 Approved By", "L1 Approved At",
              "L2 Approved By", "L2 Approved At", "Approved By", "Approved At" ].freeze

  BANK_HEADERS = [ "Bank", "Account Holder", "Account No.", "IFSC" ].freeze

  # viewer: bank columns are added for Finance; each row is filled only if the viewer may see that claim's account
  # period: optional label ("Oct-2026", "FY 2026-27") printed on the totals row
  def initialize(claims, viewer: nil, period: nil)
    @claims = claims
    @viewer = viewer
    @period = period
    @include_bank = viewer.present? && (viewer.finance? || User.exists?(finance_approver_id: viewer.id))
  end

  def headers = @include_bank ? HEADERS + BANK_HEADERS : HEADERS

  def to_xlsx
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Claims") do |sheet|
      header = sheet.styles.add_style(b: true, bg_color: "1F8445", fg_color: "FFFFFF", alignment: { wrap_text: true })
      money = sheet.styles.add_style(format_code: "#,##0.00")
      sheet.add_row headers, style: header
      rows.each do |claim|
        sheet.add_row row_for(claim), style: Array.new(7) + Array.new(8, money) + Array.new(headers.size - 15)
      end
      add_total_row(sheet, money)
      sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen; pane.y_split = 1 }
      sheet.column_widths 16, 14, 24, 18, 22, 18, 20, *Array.new(8, 14), 24, 36, 16, 22, 16, 22, 20, 22, *(@include_bank ? [ 24, 24, 20, 14 ] : [])
    end
    package.to_stream.read
  end

  def to_csv
    "﻿" + CSV.generate do |csv|
      csv << headers
      rows.each { |claim| csv << row_for(claim) }
      csv << total_row if rows.any?
    end
  end

  private

  def rows = @rows ||= @claims.to_a

  # Last line of the sheet: what the list on screen adds up to.
  def total_row
    line = Array.new(headers.size)
    line[0] = "TOTAL#{" (#{@period})" if @period}"
    line[1] = "#{rows.size} claim#{"s" unless rows.size == 1}"
    { 7 => :city_travel_total, 8 => :local_travel_total, 9 => :lodging_total, 10 => :da_total,
      11 => :incidental_total, 12 => :grand_total, 13 => :advance_amount, 14 => :balance_amount }.each do |i, attr|
      line[i] = rows.sum { |c| c.public_send(attr).to_d }
    end
    line
  end

  def add_total_row(sheet, money)
    return if rows.empty?
    bold = sheet.styles.add_style(b: true, bg_color: "E8F2EC")
    bold_money = sheet.styles.add_style(b: true, bg_color: "E8F2EC", format_code: "#,##0.00")
    sheet.add_row total_row, style: Array.new(7, bold) + Array.new(8, bold_money) + Array.new(headers.size - 15, bold)
  end

  def row_for(claim)
    [ claim.type_local? ? "Local Mileage" : "TA/DA", claim.user.emp_code, claim.user.name, claim.user.location&.name, claim.tour.duration_label, claim.status,
      claim.submitted_at&.strftime("%d/%m/%Y %H:%M"), claim.city_travel_total, claim.local_travel_total, claim.lodging_total,
      claim.da_total, claim.incidental_total, claim.grand_total, claim.advance_amount, claim.balance_amount,
      claim.l1_approved_by&.name, claim.l1_approved_at&.strftime("%d/%m/%Y %H:%M"), claim.l2_approved_by&.name,
      claim.l2_approved_at&.strftime("%d/%m/%Y %H:%M"), claim.approved_by&.name, claim.approved_at&.strftime("%d/%m/%Y %H:%M") ] + bank_cells(claim)
  end

  def bank_cells(claim)
    return [] unless @include_bank
    b = claim.bank_account if @viewer.finance? || claim.finance_approver_id == @viewer.id
    [ b&.bank_name, b&.account_holder_name, b&.account_number, b&.ifsc_code ]
  end
end
