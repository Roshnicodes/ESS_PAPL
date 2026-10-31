# TA/DA claims follow the same extra-approval rules as the tour plan (Flight → Director,
# Personal Four Wheeler → COO → Director, Train AC / Tatkal → COO): L1 → L2 → extra steps → Finance.
class ClaimExtraApprovals < ActiveRecord::Migration[8.1]
  STATUSES = %w[draft submitted l1_approved extra_pending finance_pending finance_query approved returned rejected cancelled].freeze
  OLD      = %w[draft submitted l1_approved finance_pending finance_query approved returned rejected cancelled].freeze

  def up
    create_table :claim_approval_steps do |t|
      t.references :tour_claim, null: false, foreign_key: true, index: false
      t.references :approver, null: false, foreign_key: { to_table: :users }, index: true
      t.integer  :position, null: false
      t.string   :reason, limit: 200
      t.references :acted_by, foreign_key: { to_table: :users }, index: { where: "acted_by_id IS NOT NULL" }
      t.datetime :acted_at
      t.string   :remark, limit: 500
      t.timestamps
    end
    add_index :claim_approval_steps, [ :tour_claim_id, :position ], unique: true, name: "uniq_claim_approval_steps"

    add_reference :tour_claims, :extra_approver, foreign_key: { to_table: :users }, index: false
    add_index :tour_claims, [ :extra_approver_id, :status ], where: "status = 'extra_pending' AND deleted_at IS NULL", name: "idx_tour_claims_extra_queue"

    remove_check_constraint :tour_claims, name: "chk_tour_claims_status"
    add_check_constraint :tour_claims, "status IN (#{STATUSES.map { |s| "'#{s}'" }.join(',')})", name: "chk_tour_claims_status"
    add_check_constraint :tour_claims, "status <> 'extra_pending' OR extra_approver_id IS NOT NULL", name: "chk_tour_claims_extra_pointer"
  end

  def down
    remove_check_constraint :tour_claims, name: "chk_tour_claims_extra_pointer"
    remove_check_constraint :tour_claims, name: "chk_tour_claims_status"
    add_check_constraint :tour_claims, "status IN (#{OLD.map { |s| "'#{s}'" }.join(',')})", name: "chk_tour_claims_status"
    remove_index :tour_claims, name: "idx_tour_claims_extra_queue"
    remove_reference :tour_claims, :extra_approver, foreign_key: { to_table: :users }
    drop_table :claim_approval_steps
  end
end
