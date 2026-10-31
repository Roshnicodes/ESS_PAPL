# A travel mode can need several extra approvals in order (e.g. Personal Four Wheeler → COO → Director)
# and can notify people without approval (e.g. Administration). Each tour keeps its own extra steps.
class CreateExtraApprovalChains < ActiveRecord::Migration[8.1]
  def up
    create_table :travel_mode_approvers do |t|
      t.references :travel_mode, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true, index: true
      t.string  :kind, null: false, limit: 10, default: "approve"   # approve | notify
      t.integer :position, null: false, default: 1
      t.timestamps
    end
    add_index :travel_mode_approvers, [ :travel_mode_id, :kind, :user_id ], unique: true, name: "uniq_travel_mode_approvers"
    add_check_constraint :travel_mode_approvers, "kind IN ('approve','notify')", name: "chk_travel_mode_approvers_kind"

    create_table :tour_approval_steps do |t|
      t.references :tour, null: false, foreign_key: true, index: false
      t.references :approver, null: false, foreign_key: { to_table: :users }, index: true
      t.integer  :position, null: false
      t.string   :reason, limit: 200                     # travel modes that need it, e.g. "Personal Four Wheeler"
      t.references :acted_by, foreign_key: { to_table: :users }, index: false
      t.datetime :acted_at
      t.string   :remark, limit: 500
      t.timestamps
    end
    add_index :tour_approval_steps, [ :tour_id, :position ], unique: true, name: "uniq_tour_approval_steps"

    # existing single extra approver (Flight → Director) becomes step 1 of the mode's chain
    execute <<~SQL
      INSERT INTO travel_mode_approvers (travel_mode_id, user_id, kind, position, created_at, updated_at)
      SELECT id, extra_approver_id, 'approve', 1, now(), now() FROM travel_modes WHERE extra_approver_id IS NOT NULL
    SQL
    # tours already waiting at L3 get their step row
    execute <<~SQL
      INSERT INTO tour_approval_steps (tour_id, approver_id, position, created_at, updated_at)
      SELECT id, l3_approver_id, 1, now(), now() FROM tours WHERE l3_approver_id IS NOT NULL
    SQL
  end

  def down
    drop_table :tour_approval_steps
    drop_table :travel_mode_approvers
  end
end
