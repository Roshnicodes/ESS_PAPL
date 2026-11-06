require "test_helper"

class CircularImportTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @admin = user("ADMIN"); @emp = user("1025")
    sign_in @admin
  end

  def png(name) = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/passbook.png"), "image/png", original_filename: name)

  def sheet(rows)
    path = Rails.root.join("tmp", "iom_sheet_#{SecureRandom.hex(4)}.csv")
    CSV.open(path, "w") { |csv| csv << CircularImport::TEMPLATE_HEADERS; rows.each { |r| csv << r } }
    Rack::Test::UploadedFile.new(path, "text/csv", original_filename: "old_ioms.csv")
  end

  test "template downloads" do
    get template_masters_circular_import_path
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    get new_masters_circular_import_path
    assert_response :success
    get masters_circulars_path
    assert_match new_masters_circular_import_path, response.body
  end

  test "sheet + folder in two batches: IOMs keep their old date, files attach to the right row, nothing is duplicated, no mail" do
    rows = [ [ "IOM", "ASA/HR/17", "Travel policy", "Rates revised", "01/04/2024", "All", "policy.png, annex.png", "Yes" ],
             [ "Circular", "", "Holi holiday", "", "20/03/2024", @emp.emp_code, "holi.png", "Yes" ],
             [ "IOM", "", "No date row", "", "", "All", "", "Yes" ] ]
    post masters_circular_import_path, params: { sheet: sheet(rows), files: [ png("policy.png"), png("holi.png"), png("stray.png") ] }, as: :multipart
    assert_response :success
    first = response.parsed_body
    assert_equal 2, first["created"]
    assert_equal 2, first["files_attached"]
    assert_equal [ "stray.png" ], first["unmatched_files"]
    assert first["errors"].any? { |e| e.include?("No date row") }

    post masters_circular_import_path, params: { sheet: sheet(rows), files: [ png("annex.png") ], final: "1" }, as: :multipart
    second = response.parsed_body
    assert_equal 0, second["created"]                                       # same sheet again: no duplicates
    assert_equal 1, second["files_attached"]

    policy = Circular.find_by!(topic: "Travel policy")
    assert_equal Date.new(2024, 4, 1), policy.created_at.to_date
    assert_equal %w[annex.png policy.png], policy.attachments.map { |a| a.filename.to_s }.sort
    assert_match "IOM No.: ASA/HR/17", policy.description
    holi = Circular.find_by!(topic: "Holi holiday")
    assert holi.type_circular?
    assert_equal [ @emp.id ], holi.recipients.pluck(:id)
    assert_no_enqueued_jobs(only: CircularNotifyJob)
    assert_equal 0, second["notified"]
  end

  test "without a sheet every file becomes an IOM; notification only when ticked" do
    post masters_circular_import_path, params: { files: [ png("Office_timing_2023.png") ], default_type: "circular",
                                                 default_date: "2023-06-15", final: "1", send_notification: "1" }, as: :multipart
    body = response.parsed_body
    assert_equal 1, body["created"]
    c = Circular.find_by!(topic: "Office timing 2023")
    assert c.type_circular?
    assert_equal Date.new(2023, 6, 15), c.created_at.to_date
    assert_equal 1, body["notified"]
    assert_enqueued_jobs 1, only: CircularNotifyJob
  end

  test "unknown employee code is reported and that row is not created" do
    post masters_circular_import_path, params: { sheet: sheet([ [ "IOM", "", "Secret", "", "01/01/2024", "NOPE99", "", "Yes" ] ]) }, as: :multipart
    assert response.parsed_body["errors"].first.include?("NOPE99")
    assert_nil Circular.find_by(topic: "Secret")
  end

  test "only admin can import" do
    sign_in @emp
    get new_masters_circular_import_path
    assert_response :redirect
  end
end
