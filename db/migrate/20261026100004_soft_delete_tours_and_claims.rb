# Admin delete = soft delete (kept for audit; hidden everywhere). Remark mandatory.
class SoftDeleteToursAndClaims < ActiveRecord::Migration[8.1]
  def up
    %i[tours tour_claims].each do |t|
      add_column t, :deleted_at, :datetime
      add_reference t, :deleted_by, foreign_key: { to_table: :users }, index: false
      add_column t, :delete_remark, :text
      add_index t, :deleted_at, where: "deleted_at IS NOT NULL"
      add_check_constraint t, "deleted_at IS NULL OR length(btrim(coalesce(delete_remark,''))) > 0", name: "chk_#{t}_delete_remark"
    end

    # deleted tours must not block new tours / local months
    execute "ALTER TABLE tours DROP CONSTRAINT IF EXISTS excl_tours_no_overlap"
    execute <<~SQL
      ALTER TABLE tours ADD CONSTRAINT excl_tours_no_overlap
      EXCLUDE USING gist (user_id WITH =, daterange(from_date, to_date, '[]') WITH &&)
      WHERE (tour_type = 'tour' AND status IN ('submitted','l1_approved','approved') AND deleted_at IS NULL);
    SQL
    remove_index :tours, name: "idx_tours_one_live_local_claim_per_month"
    add_index :tours, [ :user_id, :claim_month ], unique: true,
              where: "tour_type = 'local' AND status IN ('submitted','l1_approved','approved') AND deleted_at IS NULL",
              name: "idx_tours_one_live_local_claim_per_month"
    remove_index :tour_claims, :tour_id
    add_index :tour_claims, :tour_id, unique: true, where: "deleted_at IS NULL"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
