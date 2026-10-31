# Extra tour-approval rules (were set only on the development database, so the server had none):
#   Flight                  → Director
#   Personal Four Wheeler   → COO → Director, Administration manager notified
#   Train 3A / 2A / 1A      → COO
#   any train on Tatkal     → COO
# People are found by designation from the employee master. Rules already set for a mode are left alone,
# so running this again (or after HR changed the master) never overwrites anything.
class SeedExtraApprovalRules < ActiveRecord::Migration[8.1]
  def up
    coo       = person("COO")
    director  = person("Director")
    admin_mgr = User.where(active: true).where("designation ILIKE ?", "%manager%administration%").order(:id).first

    say "COO: #{coo&.name.inspect} · Director: #{director&.name.inspect} · Administration: #{admin_mgr&.name.inspect}"

    execute "UPDATE travel_modes SET is_train = true WHERE name ILIKE 'train%'"

    rule "Flight",                approve: [ director ]
    rule "Personal Four Wheeler", approve: [ coo, director ], notify: [ admin_mgr ]
    %w[Train(3A) Train(2A) Train(1A)].each { |name| rule name, approve: [ coo ] }
    TravelMode.where(is_train: true).find_each { |m| rule m.name, tatkal: [ coo ] }

    # tours already sent but not yet past L2 get their extra steps now
    Tour.where(tour_type: "tour", status: %w[submitted l1_approved]).find_each do |t|
      next if t.approval_steps.exists?
      t.send(:assign_extra_steps)
      say "Tour #{t.reference_no}: extra approval → #{t.approval_steps.map { |s| s.approver.designation.presence || s.approver.name }.join(' → ')}" if t.approval_steps.any?
    end
  end

  def down
    # rules are master data – keep them
  end

  private

  def person(designation)
    User.where(active: true).where("lower(trim(designation)) = ?", designation.downcase).order(:id).first
  end

  def rule(mode_name, approve: [], notify: [], tatkal: [])
    mode = TravelMode.where("lower(name) = ?", mode_name.downcase).first or return say("#{mode_name}: mode not found – skipped")
    TravelModeApprover.reset_column_information
    { "approve" => approve, "notify" => notify, "tatkal" => tatkal }.each do |kind, people|
      people = people.compact
      next if people.empty? || TravelModeApprover.where(travel_mode_id: mode.id, kind: kind).exists?
      people.each_with_index do |u, i|
        TravelModeApprover.create!(travel_mode_id: mode.id, user_id: u.id, kind: kind, position: i + 1)
      end
      say "#{mode.name} #{kind}: #{people.map { |u| u.designation.presence || u.name }.join(' → ')}"
    end
  end
end
