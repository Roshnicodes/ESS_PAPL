# Train visits carry the booking quota (Normal / Tatkal); a train mode can name who must approve Tatkal bookings.
class TrainQuotaAndTatkalApproval < ActiveRecord::Migration[8.1]
  def up
    add_column :travel_modes, :is_train, :boolean, null: false, default: false
    add_column :tour_visits, :ticket_quota, :string, limit: 10, null: false, default: "normal"
    add_check_constraint :tour_visits, "ticket_quota IN ('normal','tatkal')", name: "chk_tour_visits_quota"

    remove_check_constraint :travel_mode_approvers, name: "chk_travel_mode_approvers_kind"
    add_check_constraint :travel_mode_approvers, "kind IN ('approve','notify','tatkal')", name: "chk_travel_mode_approvers_kind"
    execute "UPDATE travel_modes SET is_train = true WHERE name ILIKE 'train%'"
  end

  def down
    execute "DELETE FROM travel_mode_approvers WHERE kind = 'tatkal'"
    remove_check_constraint :travel_mode_approvers, name: "chk_travel_mode_approvers_kind"
    add_check_constraint :travel_mode_approvers, "kind IN ('approve','notify')", name: "chk_travel_mode_approvers_kind"
    remove_check_constraint :tour_visits, name: "chk_tour_visits_quota"
    remove_column :tour_visits, :ticket_quota
    remove_column :travel_modes, :is_train
  end
end
