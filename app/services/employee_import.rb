require "roo"
require "etc"
require "bcrypt"

# Imports HR's "Employee details" Excel (the sheet with Employee Code / L-1 / L-2 columns).
#
#   mode :add_only (default) – employees already in the system stay exactly as they are; only new codes are added
#   mode :update             – also refresh profile + L1/L2 of existing employees
#
# L-1 = Reporting manager (tour L1 approver), L-2 = Functional manager (tour L2 approver).
class EmployeeImport
  HEADERS = {
    name:            [ "name of employee", "name", "employee name" ],
    emp_code:        [ "employee code", "emp code", "code" ],
    email:           [ "work email", "email" ],
    mobile:          [ "mobile number", "mobile" ],
    date_of_joining: [ "date of joining", "doj" ],
    department:      [ "department" ],
    designation:     [ "designation" ],
    branch:          [ "branch", "office name" ],
    sub_branch:      [ "sub branch" ],
    level:           [ "level" ],
    l1_code:         [ "l-1", "l1 code", "l1", "reporting manager" ],
    l2_code:         [ "l-2", "l2 code", "l2", "functional manager" ],
    finance_code:    [ "finance code", "finance", "pd finance" ],
    password:        [ "password", "new password", "login password" ]
  }.freeze
  NA = [ "", "#N/A", "N/A", "NA", "-", "0" ].freeze

  Result = Struct.new(:sheet, :created, :updated, :skipped, :managers_linked, :passwords, :errors, keyword_init: true) do
    def total = created + updated + skipped
  end

  DEFAULT_PASSWORD = "123456"   # employee changes it later from "Change Password"
  # Password hashing is intentionally limited so an upload does not make the
  # web server unresponsive, while still using Devise's normal BCrypt cost.
  PASSWORD_HASH_WORKERS = 6
  # Sheet passwords are hashed with BCrypt cost 10 (4× faster than the login default of 12, still the
  # recommended minimum). The cost is stored inside each hash, so login works the same; when the employee
  # later changes the password it is saved with the normal cost.
  IMPORT_BCRYPT_COST = 10
  def self.default_password(_code = nil) = DEFAULT_PASSWORD

  def initialize(path, by:, mode: :add_only, original_filename: nil)
    @path, @by, @mode = path, by, mode.to_sym
    @ext = File.extname(original_filename.presence || path).delete(".").downcase.presence || "xlsx"
  end

  def call
    book = Roo::Spreadsheet.open(@path, extension: @ext.to_sym)
    sheet_name, header_row, cols = best_sheet(book)
    raise ArgumentError, "No sheet with an 'Employee Code' column was found" unless sheet_name

    sheet = book.sheet(sheet_name)
    rows = ((header_row + 1)..sheet.last_row.to_i).filter_map do |r|
      vals = sheet.row(r)
      row = cols.transform_values { |i| clean(vals[i]) }
      row[:emp_code] = code(row[:emp_code])
      row[:l1_code]  = code(row[:l1_code])
      row[:l2_code]  = code(row[:l2_code])
      row[:finance_code] = code(row[:finance_code])
      row.merge(line: r) if row[:emp_code]
    end

    res = Result.new(sheet: sheet_name, created: 0, updated: 0, skipped: 0, managers_linked: 0, passwords: 0, errors: [])
    users_by_code = User.where("lower(emp_code) IN (?)", rows.map { |row| row[:emp_code].downcase })
                        .index_by { |user| user.emp_code.downcase }
    # BCrypt is deliberately expensive.  Hash the independent passwords before
    # opening the database transaction and across a small, bounded worker pool.
    # This makes a full employee-sheet upload substantially faster without
    # lowering the password-security cost.
    password_hashes = prehash_passwords(rows, users_by_code)
    touched = []
    existing = []
    User.transaction do
      rows.each do |row|
        user = users_by_code[row[:emp_code].downcase]
        if user && @mode == :add_only
          res.skipped += 1
          existing << [ user, row ]   # only blank L1/L2 may be filled
          reset_password(user, row, res, password_hashes[row[:line]])   # …and a password typed in the sheet
          next
        end
        is_new = user.nil?
        user ||= User.new(emp_code: row[:emp_code], role: "employee")
        user.assign_attributes(profile(row, user))
        wanted = password_for(user, row, res)
        password = wanted || (self.class.default_password(row[:emp_code]) if is_new)
        assign_password(user, password, password_hashes[row[:line]]) if password
        if user.save
          users_by_code[row[:emp_code].downcase] = user
          user.log_activity!(is_new ? :user_imported : :user_import_updated, actor: @by, details: { line: row[:line] })
          if wanted
            user.log_activity!(:user_password_set, actor: @by, details: { line: row[:line] })
            res.passwords += 1
          end
          is_new ? res.created += 1 : res.updated += 1
          touched << [ user, row ]
        else
          res.errors << "Row #{row[:line]} (#{row[:emp_code]}): #{user.errors.full_messages.to_sentence}"
        end
      end

      by_code = User.pluck(:emp_code, :id).to_h { |c, id| [ c.downcase, id ] }
      fill_blank = existing.select { |u, _| u.reporting_manager_id.nil? || u.l2_manager_id.nil? || u.finance_approver_id.nil? }
      (touched + fill_blank.map { |u, row| [ u, row, :fill ] }).each do |user, row, fill|
        l1 = by_code[row[:l1_code]&.downcase]
        l2 = by_code[row[:l2_code]&.downcase]
        fin = by_code[row[:finance_code]&.downcase]
        l1 = nil if l1 == user.id
        l2 = nil if l2 == user.id
        fin = nil if fin == user.id
        unless fill
          res.errors << "Row #{row[:line]}: L-1 code #{row[:l1_code]} not found" if row[:l1_code] && l1.nil? && row[:l1_code] != user.emp_code
          res.errors << "Row #{row[:line]}: L-2 code #{row[:l2_code]} not found" if row[:l2_code] && l2.nil? && row[:l2_code] != user.emp_code
        end
        if fill   # existing employee: keep what is set, only fill blanks
          l1 = user.reporting_manager_id || l1
          l2 = user.l2_manager_id || l2
          fin = user.finance_approver_id || fin
        end
        fin ||= user.finance_approver_id unless row.key?(:finance_code) && row[:finance_code]
        next if l1 == user.reporting_manager_id && l2 == user.l2_manager_id && fin == user.finance_approver_id
        user.update_columns(reporting_manager_id: l1, l2_manager_id: l2, finance_approver_id: fin, updated_at: Time.current)
        user.reassign_pending_finance_claims!
        res.managers_linked += 1
      end
    end
    res
  end

  private

  def best_sheet(book)
    book.sheets.filter_map do |name|
      sh = book.sheet(name)
      (1..[ sh.last_row.to_i, 10 ].min).filter_map do |r|
        heads = sh.row(r).map { |h| h.to_s.squish.downcase }
        cols = HEADERS.each_with_object({}) do |(key, names), h|
          idx = names.lazy.map { |n| heads.index(n) }.find(&:itself)
          h[key] = idx if idx
        end
        [ cols.size, name, r, cols ] if cols.key?(:emp_code) && cols.key?(:name)
      end.max_by(&:first)
    end.max_by(&:first)&.drop(1)
  end

  # Password column: blank leaves the employee's current password alone.  The
  # value is never logged – only the fact that it was set.  An admin account
  # can only be reset by another admin, so the sheet is not a way up.
  def password_for(user, row, res)
    pw = password_value(row) or return nil
    return pw unless user.persisted? && user.admin? && !@by.admin?
    res.errors << "Row #{row[:line]} (#{row[:emp_code]}): only an admin can change an admin's password"
    nil
  end

  def reset_password(user, row, res, prehashed_password = nil)
    pw = password_for(user, row, res) or return
    assign_password(user, pw, prehashed_password)
    if user.save
      user.log_activity!(:user_password_set, actor: @by, details: { line: row[:line] })
      res.passwords += 1
    else
      res.errors << "Row #{row[:line]} (#{row[:emp_code]}): password not changed – #{user.errors.full_messages.to_sentence}"
      user.reload
    end
  end

  # Hash every supplied password (and a default only for new employees) before
  # starting the write transaction. Devise::Encryptor keeps the digest format,
  # BCrypt cost and optional pepper identical to assigning user.password.
  def prehash_passwords(rows, users_by_code)
    candidates = rows.filter_map do |row|
      password = password_value(row)
      password ||= self.class.default_password(row[:emp_code]) unless users_by_code.key?(row[:emp_code].downcase)
      [ row[:line], password ] if password && password.length >= User::PASSWORD_MINIMUM_LENGTH
    end
    return {} if candidates.empty?

    jobs = Queue.new
    candidates.each { |candidate| jobs << candidate }
    hashes = {}
    mutex = Mutex.new
    workers = [ candidates.size, Etc.nprocessors, PASSWORD_HASH_WORKERS ].min
    threads = workers.times.map do
      Thread.new do
        loop do
          line, password = jobs.pop(true)
          digest = ::BCrypt::Password.create("#{password}#{User.pepper}", cost: [ IMPORT_BCRYPT_COST, User.stretches ].min).to_s
          mutex.synchronize { hashes[line] = digest }
        rescue ThreadError
          break
        rescue StandardError => e
          Thread.current[:employee_import_error] = e
          break
        end
      end
    end
    threads.each(&:join)
    error = threads.filter_map { |thread| thread[:employee_import_error] }.first
    raise error if error

    hashes
  end

  def assign_password(user, password, prehashed_password)
    # prehashed_password only comes from prehash_passwords above; invalid short
    # values use the normal assignment so the model reports its validation error.
    if prehashed_password
      # New records still validate the virtual password's presence/length. Keep
      # that value in Devise's normal virtual attribute, while reusing the
      # already-computed digest instead of hashing it again.
      user.instance_variable_set(:@password, password) unless user.persisted?
      user.encrypted_password = prehashed_password
    else
      user.password = password
    end
  end

  def password_value(row)
    pw = row[:password]
    pw = pw.to_i if pw.is_a?(Float) && pw == pw.to_i   # Excel hands 7860 back as 7860.0
    pw.to_s.strip.presence
  end

  def profile(row, user)
    {
      name: row[:name].presence || user.name,
      email: email_for(row[:email], user),
      mobile: row[:mobile]&.to_s&.first(15),
      designation: row[:designation]&.first(100),
      department: row[:department],
      branch: row[:branch],
      sub_branch: row[:sub_branch],
      level: row[:level]&.first(10),
      date_of_joining: date(row[:date_of_joining]),
      location: row[:branch] ? Location.fetch_or_create!(row[:branch]) : user.location,
      imported_at: Time.current
    }.compact
  end

  def email_for(email, user)
    email = email.to_s.strip.downcase.presence
    return nil unless email&.match?(URI::MailTo::EMAIL_REGEXP)
    User.where("lower(email) = ?", email).where.not(id: user.id).exists? ? nil : email
  end

  def clean(v)
    v = v.to_s.squish if v.is_a?(String)
    v.is_a?(String) && NA.include?(v.upcase) ? nil : v
  end

  def code(v)
    return nil if v.nil?
    v = v.to_i if v.is_a?(Float) && v == v.to_i
    v.to_s.strip.presence
  end

  def date(v)
    case v
    when Date then v
    when String then (Date.strptime(v, "%d/%m/%Y") rescue Date.parse(v) rescue nil)
    end
  end
end
