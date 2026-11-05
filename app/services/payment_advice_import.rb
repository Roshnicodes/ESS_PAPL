require "roo"

# Reads back the Payment Advice sheet PD Finance filled in and records the UTRs.
#
#   Claim ID  → which claim (the column the download puts there; "Ref No" also works)
#   UTR No.   → the bank reference; blank rows are left alone, never cleared
#   Paid On   → optional date (DD/MM/YYYY or a real Excel date)
#   Payment Remark → optional
#
# Only approved claims are touched. A claim that already has the same UTR counts as
# unchanged, a different one is recorded as a correction – both are reported.
class PaymentAdviceImport
  HEADERS = {
    claim_id: [ "claim id", "claim no", "id" ],
    ref_no:   [ "ref no", "reference no", "reference" ],
    emp_code: [ "emp code", "employee code", "code" ],
    utr_no:   [ "utr no.", "utr no", "utr", "utr number", "transaction no", "payment ref" ],
    paid_on:  [ "paid on (dd/mm/yyyy)", "paid on", "payment date", "date of payment" ],
    remark:   [ "payment remark", "remark", "narration" ]
  }.freeze

  Result = Struct.new(:recorded, :corrected, :unchanged, :skipped, :errors, keyword_init: true) do
    def total = recorded + corrected + unchanged + skipped
  end

  def initialize(path, by:, original_filename: nil)
    @path = path
    @by = by
    @ext = File.extname(original_filename.presence || path).delete(".").downcase.presence || "xlsx"
  end

  def call
    rows = read_rows
    raise ArgumentError, "No “UTR No.” column was found in the sheet" if rows.nil?

    res = Result.new(recorded: 0, corrected: 0, unchanged: 0, skipped: 0, errors: [])
    claims = claims_for(rows)

    rows.each do |row|
      utr = row[:utr_no]
      next if utr.blank?   # not paid yet – leave it exactly as it is

      claim = find_claim(claims, row)
      if claim.nil?
        res.errors << "Row #{row[:line]}: claim #{row[:claim_id] || row[:ref_no] || row[:emp_code]} not found"
        res.skipped += 1
        next
      end
      unless claim.approved?
        res.errors << "Row #{row[:line]}: claim #{claim.id} is #{claim.status}, not approved – skipped"
        res.skipped += 1
        next
      end
      if claim.utr_no.to_s == utr.upcase.gsub(/\s+/, "")
        res.unchanged += 1
        next
      end

      was_paid = claim.paid?
      if claim.record_payment!(utr: utr, by: @by, paid_on: row[:paid_on], remark: row[:remark])
        was_paid ? res.corrected += 1 : res.recorded += 1
      else
        res.errors << "Row #{row[:line]} (claim #{claim.id}): #{claim.errors.full_messages.to_sentence}"
        res.skipped += 1
      end
    end
    res
  end

  private

  def read_rows
    book = Roo::Spreadsheet.open(@path, extension: @ext.to_sym)
    book.sheets.each do |name|
      sheet = book.sheet(name)
      (1..[ sheet.last_row.to_i, 10 ].min).each do |r|
        heads = sheet.row(r).map { |h| h.to_s.squish.downcase }
        cols  = HEADERS.transform_values { |names| names.lazy.map { |n| heads.index(n) }.find(&:itself) }.compact
        next unless cols[:utr_no] && (cols[:claim_id] || cols[:ref_no] || cols[:emp_code])
        return parse(sheet, r, cols)
      end
    end
    nil
  end

  def parse(sheet, header_row, cols)
    ((header_row + 1)..sheet.last_row.to_i).filter_map do |r|
      values = sheet.row(r)
      row = cols.transform_values { |i| clean(values[i]) }
      next if row.values.all?(&:blank?)
      next if row[:claim_id].to_s.casecmp?("total") || row[:claim_id].to_s.start_with?("TOTAL")
      row[:claim_id] = row[:claim_id].to_s[/\d+/]&.to_i
      row[:paid_on]  = to_date(values[cols[:paid_on]]) if cols[:paid_on]
      row.merge(line: r)
    end
  end

  def claims_for(rows)
    ids  = rows.filter_map { |r| r[:claim_id] }
    refs = rows.filter_map { |r| r[:ref_no].presence }
    codes = rows.filter_map { |r| r[:emp_code].presence }
    scope = TourClaim.where(id: ids)
    scope = scope.or(TourClaim.where(tour_id: Tour.where(reference_no: refs).select(:id))) if refs.any?
    scope = scope.or(TourClaim.where(user_id: User.where(emp_code: codes.map(&:upcase)).select(:id))) if codes.any?
    scope.includes(:tour, :user).to_a
  end

  # Claim ID is the reliable key; reference no and employee code are fallbacks for a
  # hand-made sheet, and are used only when they point at exactly one claim.
  def find_claim(claims, row)
    return claims.find { |c| c.id == row[:claim_id] } if row[:claim_id]
    if row[:ref_no].present?
      found = claims.select { |c| c.tour.reference_no.casecmp?(row[:ref_no]) }
      return found.first if found.one?
    end
    if row[:emp_code].present?
      found = claims.select { |c| c.user.emp_code.casecmp?(row[:emp_code]) && c.approved? && !c.paid? }
      return found.first if found.one?
    end
    nil
  end

  def clean(value)
    text = value.is_a?(String) ? value.strip : value.to_s.strip
    text.presence
  end

  def to_date(value)
    return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)
    text = value.to_s.strip
    return nil if text.blank?
    [ "%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%d/%m/%y" ].each do |fmt|
      return Date.strptime(text, fmt)
    rescue Date::Error
      next
    end
    nil
  end
end
