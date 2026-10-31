class TwoLevelTourApprovalAndHrFields < ActiveRecord::Migration[8.1]
  def up
    # ---- Employee master fields from HR's Excel (Sheet1 of "Employee details") ----
    add_reference :users, :l2_manager, foreign_key: { to_table: :users }   # "Functional manager" / L-2
    add_column :users, :department,      :string, limit: 100
    add_column :users, :branch,          :string, limit: 100
    add_column :users, :sub_branch,      :string, limit: 100
    add_column :users, :date_of_joining, :date
    add_column :users, :imported_at,     :datetime
    add_index  :users, :department
    add_check_constraint :users, "l2_manager_id IS NULL OR l2_manager_id <> id", name: "chk_users_not_own_l2"

    # ---- Tour: Draft + L1 -> L2 approval ----
    remove_check_constraint :tours, name: "chk_tours_status"
    add_check_constraint :tours, "status IN ('draft','submitted','l1_approved','approved','rejected','cancelled')", name: "chk_tours_status"
    change_column_null :tours, :submitted_at, true                       # drafts are not submitted yet
    change_column_default :tours, :status, "draft"
    add_check_constraint :tours, "status = 'draft' OR status = 'cancelled' OR submitted_at IS NOT NULL", name: "chk_tours_submitted_at"

    add_reference :tours, :l2_approver,    foreign_key: { to_table: :users }, index: false
    add_reference :tours, :l1_approved_by, foreign_key: { to_table: :users }, index: false
    add_column :tours, :l1_approved_at, :datetime
    add_column :tours, :l1_remark, :text
    add_index :tours, [ :l2_approver_id, :status ]
    add_check_constraint :tours, "status <> 'l1_approved' OR l1_approved_at IS NOT NULL", name: "chk_tours_l1_at"

    # live = blocks overlap / duplicate month
    execute "ALTER TABLE tours DROP CONSTRAINT IF EXISTS excl_tours_no_overlap"
    execute <<~SQL
      ALTER TABLE tours ADD CONSTRAINT excl_tours_no_overlap
      EXCLUDE USING gist (user_id WITH =, daterange(from_date, to_date, '[]') WITH &&)
      WHERE (tour_type = 'tour' AND status IN ('submitted','l1_approved','approved'));
    SQL
    remove_index :tours, name: "idx_tours_one_live_local_claim_per_month"
    add_index :tours, [ :user_id, :claim_month ], unique: true,
              where: "tour_type = 'local' AND status IN ('submitted','l1_approved','approved')",
              name: "idx_tours_one_live_local_claim_per_month"

    # planned activity limit (500 characters)
    add_check_constraint :tour_visits, "char_length(planned_activity) <= 500", name: "chk_tour_visits_activity_len"

    # place-to-visit suggestions
    add_index :tour_visits, "lower(place)", name: "idx_tour_visits_lower_place"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
