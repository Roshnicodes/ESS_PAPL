# Local Mileage uses its own "Four Wheeler" mode – same rule as the tour's Personal Four Wheeler:
# L1 → L2 → COO → Director → Finance, Administration manager notified. Existing rules are left alone.
class SeedLocalFourWheelerRule < ActiveRecord::Migration[8.1]
  def up
    coo       = User.where(active: true).where("lower(trim(designation)) = 'coo'").order(:id).first
    director  = User.where(active: true).where("lower(trim(designation)) = 'director'").order(:id).first
    admin_mgr = User.where(active: true).where("designation ILIKE ?", "%manager%administration%").order(:id).first
    mode = TravelMode.where("lower(name) = 'four wheeler'").first or return say("Four Wheeler mode not found – skipped")

    { "approve" => [ coo, director ], "notify" => [ admin_mgr ] }.each do |kind, people|
      people = people.compact
      next if people.empty? || TravelModeApprover.where(travel_mode_id: mode.id, kind: kind).exists?
      people.each_with_index { |u, i| TravelModeApprover.create!(travel_mode_id: mode.id, user_id: u.id, kind: kind, position: i + 1) }
      say "#{mode.name} #{kind}: #{people.map { |u| u.designation.presence || u.name }.join(' → ')}"
    end
  end

  def down; end
end
