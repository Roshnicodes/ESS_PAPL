require "csv"
require "caxlsx"

# Downloadable claim report for Excel, with CSV retained for callers that
# already use the older endpoint.
class ClaimExport
  HEADERS = [ "Claim Type", "Emp Code", "Employee", "Location", "Tour Duration", "Status", "Receiving Date",
              "A. Travel", "B. Local", "C. Lodging", "D. DA", "E. Incidental", "Grand Total", "Advance", "Balance",
              "Project", "Budget Line Item", "Budget Line Item Code", "L1 Approved By", "L1 Approved At",
              "L2 Approved By", "L2 Approved At", "Approved By", "Approved At" ].freeze

  BANK_HEADERS = [ "Bank", "Account Holder", "Account No.", "IFSC" ].freeze

  # viewer: bank columns are added for Finance; each row is filled only if the viewer may see that claim's account
  def initialize(claims, viewer: nil)
    @claims = claims
    @viewer = viewer
    @include_bank = viewer.present? && (viewer.finance? || User.exists?(finance_approver_id: viewer.id))
  end

  def headers = @include_bank ? HEADERS + BANK_HEADERS : HEADERS

  def to_xlsx
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Claims") do |sheet|
      header = sheet.styles.add_style(b: true, bg_color: "1F8445", fg_color: "FFFFFF", alignment: { wrap_text: true })
      money = sheet.styles.add_style(format_code: "#,##0.00")
      sheet.add_row headers, style: header
      @claims.each do |claim|
        sheet.add_row row_for(claim), style: Array.new(7) + Array.new(8, money) + Array.new(headers.size - 15)
      end
      sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen; pane.y_split = 1 }
      sheet.column_widths 16, 14, 24, 18, 22, 18, 20, *Array.new(8, 14), 24, 36, 16, 22, 16, 22, 20, 22, *(@include_bank ? [ 24, 24, 20, 14 ] : [])
    end
    package.to_stream.read
  end

  def to_csv
    "﻿" + CSV.generate do |csv|
      csv << headers
      @claims.each { |claim| csv << row_for(claim) }
    end
  end

  private

  def row_for(claim)
    [ claim.type_local? ? "Local Mileage" : "TA/DA", claim.user.emp_code, claim.user.name, claim.user.location&.name, claim.tour.duration_label, claim.status,
      claim.submitted_at&.strftime("%d/%m/%Y %H:%M"), claim.city_travel_total, claim.local_travel_total, claim.lodging_total,
      claim.da_total, claim.incidental_total, claim.grand_total, claim.advance_amount, claim.balance_amount,
      claim.project&.name, claim.budget_line_item&.name, claim.budget_line_item_code&.name,
      claim.l1_approved_by&.name, claim.l1_approved_at&.strftime("%d/%m/%Y %H:%M"), claim.l2_approved_by&.name,
      claim.l2_approved_at&.strftime("%d/%m/%Y %H:%M"), claim.approved_by&.name, claim.approved_at&.strftime("%d/%m/%Y %H:%M") ] + bank_cells(claim)
  end

  def bank_cells(claim)
    return [] unless @include_bank
    b = claim.bank_account if @viewer.finance? || claim.finance_approver_id == @viewer.id
    [ b&.bank_name, b&.account_holder_name, b&.account_number, b&.ifsc_code ]
  end
end
