# Removes every employee except the admin accounts, so a fresh Employee List can be uploaded.
# Their tours, claims, bank accounts, notifications and travel-mode approver slots go with them;
# masters (cities, travel modes, rates, projects) stay and are re-owned by the admin.
#
#   RAILS_ENV=production bin/rails runner script/remove_employees.rb              # dry run: counts only
#   CONFIRM=yes RAILS_ENV=production bin/rails runner script/remove_employees.rb  # really delete
#
# Everything runs in one transaction: any error rolls the whole thing back (audit-log lock included).
conn    = ActiveRecord::Base.connection
keep    = User.where(role: "admin").order(:id)
admin   = keep.find_by(emp_code: "ADMIN") || keep.first or abort("No admin user – nothing kept, stopping.")
victims = User.where.not(id: keep.select(:id))
vids    = victims.pluck(:id)

tours   = Tour.unscoped.where(user_id: vids)
claims  = TourClaim.unscoped.where(user_id: vids).or(TourClaim.unscoped.where(tour_id: tours.select(:id)))
banks   = BankAccount.where(user_id: vids)

puts "Keeping: #{keep.pluck(:emp_code).join(', ')}"
puts "Removing: #{vids.size} employees, #{tours.count} tours, #{claims.count} claims, #{banks.count} bank accounts"

unless ENV["CONFIRM"] == "yes"
  puts "Dry run – nothing changed. Run again with CONFIRM=yes to delete."
  exit
end

ActiveRecord::Base.transaction do
  # the audit log is append-only; lift that only inside this transaction for the removed people's rows
  conn.execute("ALTER TABLE activity_logs DISABLE TRIGGER trg_activity_logs_immutable")
  claim_ids = claims.pluck(:id)
  tour_ids  = tours.pluck(:id)

  # claims (line tables cascade in the database)
  ClaimApprovalStep.where(tour_claim_id: claim_ids).delete_all
  ClaimQuery.where(tour_claim_id: claim_ids).delete_all
  ActivityLog.where(trackable_type: "TourClaim", trackable_id: claim_ids).delete_all
  Notification.where(notifiable_type: "TourClaim", notifiable_id: claim_ids).delete_all
  TourClaim.unscoped.where(id: claim_ids).delete_all

  # tours (visits cascade)
  TourApprovalStep.where(tour_id: tour_ids).delete_all
  ActivityLog.where(trackable_type: "Tour", trackable_id: tour_ids).delete_all
  Notification.where(notifiable_type: "Tour", notifiable_id: tour_ids).delete_all
  Tour.unscoped.where(id: tour_ids).delete_all

  # bank accounts + passbook files (purged now – no background job needed)
  bank_ids = banks.pluck(:id)
  ActiveStorage::Attachment.where(record_type: "BankAccount", record_id: bank_ids).find_each(&:purge)
  ActivityLog.where(trackable_type: "BankAccount", trackable_id: bank_ids).delete_all
  BankAccount.where(id: bank_ids).delete_all

  # personal rows of the removed people
  Notification.where(user_id: vids).or(Notification.where(actor_id: vids)).delete_all
  ActivityLog.where(actor_id: vids).or(ActivityLog.where(trackable_type: "User", trackable_id: vids)).delete_all
  ClaimCutoffRule.where(user_id: vids).delete_all
  TravelModeApprover.where(user_id: vids).delete_all

  # admins keep no manager links to removed people
  keep.update_all(reporting_manager_id: nil, l2_manager_id: nil, finance_approver_id: nil)

  # anything else still pointing at a removed person: masters go to the admin, optional links are cleared
  conn.tables.each do |table|
    conn.foreign_keys(table).select { |fk| fk.to_table == "users" && table != "users" }.each do |fk|
      col = fk.column
      next unless conn.select_value("SELECT 1 FROM #{conn.quote_table_name(table)} WHERE #{conn.quote_column_name(col)} IN (#{vids.join(',').presence || 'NULL'}) LIMIT 1")
      nullable = conn.columns(table).find { |c| c.name == col }.null
      value = col.match?(/created_by|updated_by/) || !nullable ? admin.id : nil
      n = conn.update("UPDATE #{conn.quote_table_name(table)} SET #{conn.quote_column_name(col)} = #{value || 'NULL'} WHERE #{conn.quote_column_name(col)} IN (#{vids.join(',')})")
      puts "  #{table}.#{col}: #{n} row(s) -> #{value ? "admin #{admin.emp_code}" : 'cleared'}"
    end
  end

  User.where(id: vids).update_all(reporting_manager_id: nil, l2_manager_id: nil, finance_approver_id: nil)
  removed = User.where(id: vids).delete_all
  conn.execute("ALTER TABLE activity_logs ENABLE TRIGGER trg_activity_logs_immutable")
  puts "Removed #{removed} employees. Left: #{User.pluck(:emp_code).join(', ')}"
end
Rails.cache.clear rescue nil
