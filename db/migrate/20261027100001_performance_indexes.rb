# Speed: indexes for every remaining FK + the filters/sorts the pages actually run.
class PerformanceIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # FKs that had no index
    add_index :tours, :l1_approved_by_id, where: "l1_approved_by_id IS NOT NULL", algorithm: :concurrently
    add_index :tours, :returned_by_id,    where: "returned_by_id IS NOT NULL", algorithm: :concurrently
    add_index :tours, :deleted_by_id,     where: "deleted_by_id IS NOT NULL", algorithm: :concurrently
    add_index :tour_claims, :returned_by_id, where: "returned_by_id IS NOT NULL", algorithm: :concurrently
    add_index :tour_claims, :deleted_by_id,  where: "deleted_by_id IS NOT NULL", algorithm: :concurrently
    add_index :notifications, :actor_id, algorithm: :concurrently

    # "Tour Approval History": my actions on tours
    add_index :activity_logs, [ :actor_id, :trackable_type, :action, :trackable_id ],
              name: "idx_activity_logs_actor_type_action", algorithm: :concurrently
    # dashboard "my recent actions" already uses (actor_id, created_at)

    # Admin "All Tours" list + search
    add_index :tours, :created_at, order: { created_at: :desc }, algorithm: :concurrently
    add_index :tours, :reference_no, using: :gin, opclass: :gin_trgm_ops, name: "idx_tours_reference_trgm", algorithm: :concurrently
    add_index :users, :emp_code, using: :gin, opclass: :gin_trgm_ops, name: "idx_users_emp_code_trgm", algorithm: :concurrently

    # claim lists ordered by submission / approval per type
    add_index :tour_claims, [ :claim_type, :status, :submitted_at ], algorithm: :concurrently
    # employee's own lists (Tour History)
    add_index :tours, [ :user_id, :tour_type, :from_date ], order: { from_date: :desc }, algorithm: :concurrently
  end
end
