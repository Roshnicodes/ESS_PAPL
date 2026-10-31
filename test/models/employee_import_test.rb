require "test_helper"
require "caxlsx"

class EmployeeImportTest < ActiveSupport::TestCase
  def xlsx(rows)
    pkg = Axlsx::Package.new
    pkg.workbook.add_worksheet(name: "Sheet1") do |ws|
      ws.add_row EmployeeExport::HEADERS
      rows.each { |r| ws.add_row r }
    end
    path = Rails.root.join("tmp/test_import_#{SecureRandom.hex(4)}.xlsx").to_s
    pkg.serialize(path)
    path
  end

  test "adds new employees with L1/L2, keeps existing unchanged" do
    hr = user("HR001")
    existing = user("AM001")
    path = xlsx([
      [ "Sunil Mehta", 840, "k.t@example.org", "8959591213", "01/08/2018", "Operations", "COO", "HO- Bhopal", "HO- Bhopal", "L-1", "", "#N/A", "", "", "#N/A", "" ],
      [ "Pritesh Jain", 25, "p.j@example.org", "7000778069", "16/04/2007", "LWRD", "FCO Coordinator", "FCO-Ranapur", "FCO-Ranapur", "L-2", 840, 840, "Krishn", "", "#N/A", "" ],
      [ "Makhan Singh", 1724, "", "7860345972", "26/09/2025", "Project", "FCO Coordinator", "FCO-Kotma", "TO-Kotma", "L-3", 25, 25, "Pritesh", 840, 840, "Krishn" ],
      [ "Changed Name", "AM001", "", "", "", "", "", "", "", "", "", "", "", "", "", "" ]
    ])
    res = EmployeeImport.new(path, by: hr).call
    assert_equal [ 3, 0, 1 ], [ res.created, res.updated, res.skipped ]
    makhan = User.find_by!(emp_code: "1724")
    assert_equal "25", makhan.reporting_manager.emp_code
    assert_equal "840", makhan.l2_manager.emp_code
    assert_equal "L-3", makhan.level
    assert_equal Date.new(2025, 9, 26), makhan.date_of_joining
    assert makhan.valid_password?("123456")
    assert_equal "Amit Verma", existing.reload.name           # existing kept as is

    res2 = EmployeeImport.new(path, by: hr).call                # re-upload: nothing duplicated
    assert_equal [ 0, 4 ], [ res2.created, res2.skipped ]

    res3 = EmployeeImport.new(path, by: hr, mode: :update).call
    assert_equal "Changed Name", existing.reload.name
    assert_equal 4, res3.updated
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  # Password column: blank keeps the current password, a value sets it – and it
  # works even in add_only mode, where nothing else about the row is touched.
  test "password column sets the login password, blank leaves it alone" do
    hr = user("HR001")
    existing = user("AM001")
    existing.update!(password: "oldpass1")
    path = xlsx([
      [ "New Person", 7701, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "fresh123" ],
      [ "Amit Verma", "AM001", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "newpass9" ],
      [ "No Password", 7702, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "" ]
    ])
    res = EmployeeImport.new(path, by: hr).call

    assert_equal 2, res.passwords
    assert_empty res.errors
    assert User.find_by!(emp_code: "7701").valid_password?("fresh123")
    assert existing.reload.valid_password?("newpass9"), "add_only mode must still honour the Password column"
    assert User.find_by!(emp_code: "7702").valid_password?("123456")   # blank → the default for a new employee
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "a password under three characters is refused and the old one kept" do
    hr = user("HR001")
    existing = user("AM001")
    existing.update!(password: "oldpass1")
    path = xlsx([ [ "Amit Verma", "AM001", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "12" ] ])
    res = EmployeeImport.new(path, by: hr).call

    assert_equal 0, res.passwords
    assert_match(/too short/, res.errors.join)
    assert existing.reload.valid_password?("oldpass1")
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "a numeric password keeps the digits Excel turned into a float" do
    hr = user("HR001")
    path = xlsx([ [ "Numeric Pass", 7703, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", 90901234 ] ])
    EmployeeImport.new(path, by: hr).call
    assert User.find_by!(emp_code: "7703").valid_password?("90901234")
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "three- and four-character passwords from the HR sheet can log in" do
    hr = user("HR001")
    path = xlsx([
      [ "Short Password", 7704, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "a1b" ],
      [ "Four Digit Password", 7705, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "7860" ]
    ])
    res = EmployeeImport.new(path, by: hr).call

    assert_equal 2, res.passwords
    assert User.find_by!(emp_code: "7704").valid_password?("a1b")
    assert User.find_by!(emp_code: "7705").valid_password?("7860")
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "a non-admin cannot reset an admin password through the sheet" do
    hr = user("HR001")
    admin = User.find_by!(role: "admin")
    admin.update!(password: "adminpass1")
    path = xlsx([ [ admin.name, admin.emp_code, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "hacked99" ] ])
    res = EmployeeImport.new(path, by: hr).call

    assert_equal 0, res.passwords
    assert_match(/only an admin/, res.errors.join)
    assert admin.reload.valid_password?("adminpass1")
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "export downloads an xlsx with the same headers" do
    data = EmployeeExport.new(User.all).to_xlsx
    path = Rails.root.join("tmp/export_test.xlsx").to_s
    File.binwrite(path, data)
    sheet = Roo::Excelx.new(path).sheet(0)
    assert_equal EmployeeExport::HEADERS, sheet.row(1)
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
