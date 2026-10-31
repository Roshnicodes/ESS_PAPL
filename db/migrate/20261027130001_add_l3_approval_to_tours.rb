# Extra (L3) tour approval: a travel mode (e.g. Flight) can name an approver who signs after L1 → L2.
class AddL3ApprovalToTours < ActiveRecord::Migration[8.1]
  LIVE_OLD = "'submitted','l1_approved','approved'"
  LIVE_NEW = "'submitted','l1_approved','l2_approved','approved'"

  def up
    add_reference :travel_modes, :extra_approver, foreign_key: { to_table: :users }, index: true

    add_reference :tours, :l3_approver,    foreign_key: { to_table: :users }, index: true
    add_reference :tours, :l2_approved_by, foreign_key: { to_table: :users }, index: true
    add_column    :tours, :l2_approved_at, :datetime
    add_column    :tours, :l2_remark, :string, limit: 500

    remove_check_constraint :tours, name: "chk_tours_status"
    add_check_constraint :tours, "status IN ('draft','submitted','l1_approved','l2_approved','approved','returned','rejected','cancelled')", name: "chk_tours_status"
    add_check_constraint :tours, "status <> 'l2_approved' OR (l2_approved_at IS NOT NULL AND l3_approver_id IS NOT NULL)", name: "chk_tours_l2_at"

    # overlapping live tours are still blocked while waiting for L3
    execute "ALTER TABLE tours DROP CONSTRAINT excl_tours_no_overlap"
    execute <<~SQL
      ALTER TABLE tours ADD CONSTRAINT excl_tours_no_overlap EXCLUDE USING gist
        (user_id WITH =, daterange(from_date, to_date, '[]') WITH &&)
        WHERE (tour_type = 'tour' AND status IN (#{LIVE_NEW}) AND deleted_at IS NULL)
    SQL

    # Pending Tour Approval for the L3 person
    add_index :tours, [ :l3_approver_id, :status ], where: "status = 'l2_approved' AND deleted_at IS NULL", name: "idx_tours_l3_queue"
  end

  def down
    remove_index :tours, name: "idx_tours_l3_queue"
    execute "ALTER TABLE tours DROP CONSTRAINT excl_tours_no_overlap"
    execute <<~SQL
      ALTER TABLE tours ADD CONSTRAINT excl_tours_no_overlap EXCLUDE USING gist
        (user_id WITH =, daterange(from_date, to_date, '[]') WITH &&)
        WHERE (tour_type = 'tour' AND status IN (#{LIVE_OLD}) AND deleted_at IS NULL)
    SQL
    remove_check_constraint :tours, name: "chk_tours_l2_at"
    remove_check_constraint :tours, name: "chk_tours_status"
    add_check_constraint :tours, "status IN ('draft','submitted','l1_approved','approved','returned','rejected','cancelled')", name: "chk_tours_status"
    remove_column :tours, :l2_remark
    remove_column :tours, :l2_approved_at
    remove_reference :tours, :l2_approved_by, foreign_key: { to_table: :users }
    remove_reference :tours, :l3_approver, foreign_key: { to_table: :users }
    remove_reference :travel_modes, :extra_approver, foreign_key: { to_table: :users }
  end
end
