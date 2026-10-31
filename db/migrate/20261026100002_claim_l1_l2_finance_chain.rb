# Claim chain = L1 -> L2 (if set) -> PD Finance. MIS verification step removed.
class ClaimL1L2FinanceChain < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :tour_claims, name: "chk_claims_status"
    execute "UPDATE tour_claims SET status = CASE status WHEN 'verified' THEN 'l1_approved' WHEN 'recommended' THEN 'finance_pending' ELSE status END"
    add_check_constraint :tour_claims,
      "status IN ('draft','submitted','l1_approved','finance_pending','approved','rejected','cancelled')", name: "chk_claims_status"

    remove_index :tour_claims, [ :verifier_id, :status ]
    remove_index :tour_claims, [ :recommender_id, :status ]
    rename_column :tour_claims, :verifier_id,       :l1_approver_id
    rename_column :tour_claims, :recommender_id,    :l2_approver_id
    rename_column :tour_claims, :verified_at,       :l1_approved_at
    rename_column :tour_claims, :verified_by_id,    :l1_approved_by_id
    rename_column :tour_claims, :recommended_at,    :l2_approved_at
    rename_column :tour_claims, :recommended_by_id, :l2_approved_by_id
    add_index :tour_claims, [ :l1_approver_id, :status ]
    add_index :tour_claims, [ :l2_approver_id, :status ]
    add_column :tour_claims, :l1_remark, :text
    add_column :tour_claims, :l2_remark, :text
    add_column :tour_claims, :finance_remark, :text
    add_check_constraint :tour_claims, "status <> 'l1_approved' OR (l1_approved_at IS NOT NULL AND l2_approver_id IS NOT NULL)", name: "chk_claims_l1"
    add_check_constraint :tour_claims, "status <> 'submitted' OR l1_approver_id IS NOT NULL", name: "chk_claims_submitted_l1"

    # MIS "claim verifier" is no longer used
    remove_reference :users, :claim_verifier, foreign_key: { to_table: :users }, index: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
