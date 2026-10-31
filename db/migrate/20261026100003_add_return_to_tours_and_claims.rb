# Approver actions = Approve / Return (back to employee, can be corrected & re-sent) / Reject (final). Remark mandatory.
class AddReturnToToursAndClaims < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :tours, name: "chk_tours_status"
    add_check_constraint :tours, "status IN ('draft','submitted','l1_approved','approved','returned','rejected','cancelled')", name: "chk_tours_status"
    add_column :tours, :returned_at, :datetime
    add_reference :tours, :returned_by, foreign_key: { to_table: :users }, index: false
    add_column :tours, :return_remark, :text
    add_check_constraint :tours, "status <> 'returned' OR (returned_at IS NOT NULL AND length(btrim(coalesce(return_remark,''))) > 0)", name: "chk_tours_return_remark"
    add_check_constraint :tours, "status <> 'rejected' OR length(btrim(coalesce(decision_remark,''))) > 0", name: "chk_tours_reject_remark"

    remove_check_constraint :tour_claims, name: "chk_claims_status"
    add_check_constraint :tour_claims,
      "status IN ('draft','submitted','l1_approved','finance_pending','approved','returned','rejected','cancelled')", name: "chk_claims_status"
    add_column :tour_claims, :returned_at, :datetime
    add_reference :tour_claims, :returned_by, foreign_key: { to_table: :users }, index: false
    add_column :tour_claims, :return_remark, :text
    add_check_constraint :tour_claims, "status <> 'returned' OR (returned_at IS NOT NULL AND length(btrim(coalesce(return_remark,''))) > 0)", name: "chk_claims_return_remark"
    add_check_constraint :tour_claims, "status <> 'rejected' OR length(btrim(coalesce(reject_remark,''))) > 0", name: "chk_claims_reject_remark"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
