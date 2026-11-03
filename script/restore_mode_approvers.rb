# Puts back the travel-mode approvers (approve / notify / tatkal) from a pg_dump backup, matching people by
# employee code – for use after the Employee List was removed and uploaded again (new user ids).
# Only travel modes that have no approvers now are filled; anything already set again is left alone.
#
#   BACKUP=/root/ess_papl_backup.sql RAILS_ENV=production bin/rails runner script/restore_mode_approvers.rb              # dry run
#   BACKUP=/root/ess_papl_backup.sql CONFIRM=yes RAILS_ENV=production bin/rails runner script/restore_mode_approvers.rb  # write
path = ENV["BACKUP"].to_s
abort("Set BACKUP=/path/to/backup.sql") unless File.file?(path)

# rows of one "COPY public.<table> (cols) FROM stdin;" block as hashes (\N = NULL)
def copy_rows(path, table)
  rows, cols = [], nil
  File.foreach(path) do |line|
    if cols.nil?
      m = line.match(/\ACOPY public\.#{table} \((.+)\) FROM stdin;/) and cols = m[1].split(", ").map { _1.delete('"') }
    else
      break if line.start_with?("\\.")
      rows << cols.zip(line.chomp.split("\t", -1).map { _1 == "\\N" ? nil : _1 }).to_h
    end
  end
  rows
end

old_code  = copy_rows(path, "users").to_h { [ _1["id"], _1["emp_code"] ] }
old_modes = copy_rows(path, "travel_modes").to_h { [ _1["id"], _1["name"] ] }
saved     = copy_rows(path, "travel_mode_approvers").group_by { old_modes[_1["travel_mode_id"]] }
abort("No travel mode approvers in the backup.") if saved.empty?

plan, missing = [], []
saved.each do |mode_name, rows|
  mode = TravelMode.find_by(name: mode_name) or (missing << "mode #{mode_name}"; next)
  if mode.mode_approvers.exists?
    puts "#{mode_name}: already has approvers now – left as it is"
    next
  end
  rows.sort_by { [ _1["kind"], _1["position"].to_i ] }.each do |r|
    code = old_code[r["user_id"]]
    user = User.find_by(emp_code: code)
    user ? plan << [ mode, user, r["kind"], r["position"].to_i ] : missing << "#{mode_name} #{r['kind']}: #{code} not in the new Employee List"
  end
end

plan.group_by(&:first).each { |mode, items| puts "#{mode.name}: " + items.map { |_, u, k, p| "#{k}##{p} #{u.name} (#{u.emp_code})" }.join(", ") }
missing.each { puts "SKIPPED – #{_1}" }

unless ENV["CONFIRM"] == "yes"
  puts "Dry run – nothing changed. Run again with CONFIRM=yes to restore."
  exit
end

ActiveRecord::Base.transaction do
  plan.each { |mode, user, kind, pos| mode.mode_approvers.create!(user_id: user.id, kind: kind, position: pos) }
end
puts "Restored #{plan.size} approver slot(s)."
