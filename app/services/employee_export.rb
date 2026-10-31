require "caxlsx"

# Same columns as HR's "Employee details" Sheet1, so the file can be edited and uploaded back.
class EmployeeExport
  HEADERS = [ "Name of Employee", "Employee Code", "Work email", "Mobile number", "Date of joining", "Department",
              "Designation", "Branch", "Sub branch", "Level", "Reporting manager", "L-1", "Name", "Functional manager",
              "L-2", "Functional manager Name", "Finance Code", "Finance Name", "Password" ].freeze

  def initialize(users) = @users = users

  def to_xlsx
    pkg = Axlsx::Package.new
    pkg.workbook.add_worksheet(name: "Sheet1") do |ws|
      head = ws.styles.add_style(b: true, bg_color: "1D67EB", fg_color: "FFFFFF", alignment: { wrap_text: true })
      ws.add_row HEADERS, style: head
      @users.includes(:reporting_manager, :l2_manager, :finance_approver).find_each do |u|
        l1, l2, fin = u.reporting_manager, u.l2_manager, u.finance_approver
        ws.add_row [ u.name, u.emp_code, u.email, u.mobile, u.date_of_joining&.strftime("%d/%m/%Y"), u.department,
                     u.designation, u.branch, u.sub_branch, u.level, l1&.emp_code, l1&.emp_code, l1&.name,
                     l2&.emp_code, l2&.emp_code, l2&.name, fin&.emp_code, fin&.name, nil ],
                   types: Array.new(HEADERS.size, :string)
      end
      ws.sheet_view.pane { |p| p.top_left_cell = "A2"; p.state = :frozen; p.y_split = 1 }
    end
    pkg.to_stream.read
  end
end
