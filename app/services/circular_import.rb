require "roo"

# Bulk import of OLD IOMs / Circulars: an optional Excel sheet (one row per IOM) + the files of a folder.
#
#   With the sheet  → each row becomes one IOM; its "File names" cell says which uploaded files belong to it.
#   Without a sheet → every uploaded file becomes one IOM, topic = file name, date / type from the form.
#
# The browser sends a big folder in several batches (each with the same sheet), so the import is
# idempotent: an IOM is found again by type + topic + date and only files it does not already have
# are attached. The IOM's date (the old issue date) is kept as its created_at, so the lists stay in
# date order; the activity log records when and by whom it was imported.
class CircularImport
  HEADERS = {
    type:        [ "type", "iom / circular", "iom/circular", "topic type" ],
    number:      [ "iom / circular no.", "iom no", "iom no.", "circular no", "circular no.", "no", "no.", "number", "ref no", "ref no.", "reference" ],
    topic:       [ "topic", "subject", "title" ],
    description: [ "description", "details" ],
    date:        [ "date", "issued on", "issue date", "date (dd/mm/yyyy)" ],
    send_to:     [ "send to", "audience", "employees", "employee codes" ],
    files:       [ "file names", "file name", "files", "file", "attachments", "attachment" ],
    active:      [ "active", "status" ]
  }.freeze
  TEMPLATE_HEADERS = [ "Type", "IOM / Circular No.", "Topic", "Description", "Date", "Send to", "File names", "Active" ].freeze

  Result = Struct.new(:created, :files_attached, :already, :errors, :unmatched_files, :created_ids, keyword_init: true)

  def initialize(by:, files: [], sheet_path: nil, sheet_name: nil, default_type: "iom", default_date: nil)
    @by = by
    @files = Array(files).reject(&:blank?)
    @sheet_path, @sheet_name = sheet_path, sheet_name
    @default_type = Circular::TYPES.value?(default_type.to_s) ? default_type.to_s : "iom"
    @default_date = default_date || Date.current
  end

  def call
    res = Result.new(created: 0, files_attached: 0, already: 0, errors: [], unmatched_files: [], created_ids: [])
    rows = @sheet_path ? sheet_rows(res) : file_rows
    by_name = @files.index_by { |f| key(f.original_filename) }
    used = []

    rows.each do |row|
      import_row(row, by_name, used, res)
    rescue ActiveRecord::RecordInvalid => e
      res.errors << "#{row[:label]}: #{e.record.errors.full_messages.to_sentence}"
    end
    res.unmatched_files = (by_name.keys - used).map { |k| by_name[k].original_filename } if @sheet_path
    res
  end

  def self.template_xlsx
    pkg = Axlsx::Package.new
    pkg.workbook.add_worksheet(name: "IOMs") do |ws|
      head = ws.styles.add_style(b: true, bg_color: "1F8445", fg_color: "FFFFFF")
      text = ws.styles.add_style(format_code: "@")
      ws.add_row TEMPLATE_HEADERS, style: head
      ws.add_row [ "IOM", "PAPL/HR/2024/017", "Revised travel policy", "TA/DA rates revised from 1 April 2024.", "01/04/2024", "All", "travel_policy_2024.pdf", "Yes" ], style: text
      ws.add_row [ "Circular", "", "Office closed on Holi", "", "20/03/2024", "1025, 1752", "holi_notice.pdf, holi_list.xlsx", "Yes" ], style: text
      ws.column_widths 10, 20, 34, 40, 13, 18, 40, 8
    end
    pkg.workbook.add_worksheet(name: "How to fill") do |ws|
      [ [ "Column", "What to write" ],
        [ "Type", "IOM or Circular (blank = IOM)" ],
        [ "IOM / Circular No.", "Optional – the number printed on the IOM; it is shown at the start of the description" ],
        [ "Topic", "Required – the subject" ],
        [ "Description", "Optional" ],
        [ "Date", "Required – the date of the IOM, dd/mm/yyyy (lists are sorted by it)" ],
        [ "Send to", "All (or blank) = every employee; otherwise employee codes separated by commas" ],
        [ "File names", "Exact file names in the folder you upload, separated by commas (e.g. iom_17.pdf, annexure.xlsx)" ],
        [ "Active", "Yes / No (blank = Yes). No = kept but hidden from employees" ],
        [ "", "" ],
        [ "Upload", "Masters → IOM / Circular → Import old IOMs: choose this sheet and the folder with the files. Uploading again does not make duplicates." ] ]
        .each_with_index { |r, i| ws.add_row r, style: (i.zero? ? ws.styles.add_style(b: true) : nil) }
      ws.column_widths 22, 100
    end
    pkg.to_stream.read
  end

  private

  def import_row(row, by_name, used, res)
    circular = existing(row) || build(row)
    wanted = row[:files].map { |n| key(n) }
    files = if @sheet_path
      wanted.filter_map { |k| by_name[k] }
    else
      [ by_name[key(row[:file])] ].compact
    end
    used.concat(files.map { |f| key(f.original_filename) })
    have = circular.persisted? ? circular.attachments.map { |a| key(a.filename.to_s) } : []
    new_files = files.reject { |f| have.include?(key(f.original_filename)) }
    too_big = new_files.select { |f| f.size > Circular::ATTACHMENT_MAX }
    too_big.each { |f| res.errors << "#{f.original_filename}: larger than #{Circular::ATTACHMENT_MAX / 1.megabyte} MB – not attached" }
    new_files -= too_big

    if circular.new_record?
      circular.attachments.attach(new_files) if new_files.any?
      circular.save!
      circular.update_columns(created_at: row[:date].in_time_zone.change(hour: 10), updated_at: Time.current)
      circular.log_activity!(:circular_imported, actor: @by, details: { topic: circular.topic, date: row[:date].to_s, files: new_files.size })
      res.created += 1
      res.created_ids << circular.id
    else
      if new_files.any?
        circular.attachments.attach(new_files)
        circular.log_activity!(:circular_files_imported, actor: @by, details: { files: new_files.map(&:original_filename) })
      end
      res.already += 1
    end
    res.files_attached += new_files.size
  end

  def existing(row)
    Circular.where(topic_type: row[:type]).where("LOWER(topic) = ?", row[:topic].downcase)
            .where(created_at: row[:date].in_time_zone.all_day).first
  end

  def build(row)
    c = Circular.new(topic_type: row[:type], topic: row[:topic], description: row[:description], active: row[:active],
                     created_by: @by, audience: row[:codes].empty? ? "all" : "selected")
    if row[:codes].any?
      users = User.where("LOWER(emp_code) IN (?)", row[:codes].map(&:downcase)).to_a
      found = users.map { |u| u.emp_code.downcase }
      missing = row[:codes].reject { |code| found.include?(code.downcase) }
      raise_invalid(c, "unknown employee code(s): #{missing.join(', ')}") if missing.any?
      users.each { |u| c.circular_recipients.build(user: u) }
    end
    c
  end

  def raise_invalid(record, message)
    record.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, record
  end

  # Without a sheet: one IOM per file, topic from the file name.
  def file_rows
    @files.map do |f|
      name = File.basename(f.original_filename.to_s, ".*").tr("_", " ").squish.presence || f.original_filename
      { label: f.original_filename, type: @default_type, topic: name.truncate(200), description: nil, date: @default_date,
        codes: [], active: true, files: [], file: f.original_filename }
    end
  end

  def sheet_rows(res)
    ext = File.extname(@sheet_name.to_s).delete(".").downcase.presence || "xlsx"
    sheet = Roo::Spreadsheet.open(@sheet_path, extension: ext.to_sym).sheet(0)
    header_row = (1..[ sheet.last_row.to_i, 10 ].min).find { |r| column_map(sheet.row(r)).key?(:topic) }
    raise ArgumentError, "No “Topic” column found in the sheet" unless header_row
    cols = column_map(sheet.row(header_row))
    ((header_row + 1)..sheet.last_row.to_i).filter_map do |r|
      cell = ->(k) { cols[k] ? sheet.row(r)[cols[k]] : nil }
      topic = cell.(:topic).to_s.squish
      next if topic.blank?
      label = "Row #{r} (#{topic.truncate(40)})"
      date = parse_date(cell.(:date))
      unless date
        res.errors << "#{label}: date missing or not dd/mm/yyyy – skipped"
        next
      end
      number = cell.(:number).to_s.squish
      desc = [ ("#{type_of(cell.(:type)) == 'circular' ? 'Circular' : 'IOM'} No.: #{number}" if number.present?), cell.(:description).to_s.strip.presence ].compact.join("\n")
      send_to = cell.(:send_to).to_s.squish
      codes = send_to.blank? || send_to.casecmp?("all") || send_to.casecmp?("all employees") ? [] : send_to.split(/[,;\s]+/).map { |c| c.sub(/\.0\z/, "") }.reject(&:blank?)
      { label: label, type: type_of(cell.(:type)), topic: topic.truncate(200), description: desc.presence, date: date, codes: codes,
        active: !cell.(:active).to_s.strip.downcase.in?(%w[no n false 0 inactive]),
        files: cell.(:files).to_s.split(/[,;|\n]+/).map(&:strip).reject(&:blank?) }
    end
  end

  def type_of(value) = value.to_s.strip.downcase.start_with?("circ") ? "circular" : (value.to_s.strip.empty? ? @default_type : "iom")

  def parse_date(value)
    return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)
    text = value.to_s.strip
    return if text.empty?
    Date.strptime(text.tr(".-", "//"), "%d/%m/%Y")
  rescue ArgumentError, Date::Error
    begin
      Date.parse(text)
    rescue ArgumentError, Date::Error
      nil
    end
  end

  def key(name) = File.basename(name.to_s).strip.downcase

  def column_map(row)
    row.each_with_index.each_with_object({}) do |(cell, i), map|
      label = cell.to_s.strip.downcase
      HEADERS.each { |k, names| map[k] ||= i if names.include?(label) }
    end
  end
end
