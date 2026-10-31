# Every foreign key gets an index (fast joins, fast user/master deletes checks).
class AddMissingFkIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :claim_queries, :asked_by_id, algorithm: :concurrently, if_not_exists: true
    add_index :claim_queries, :asked_to_id, where: "answered_at IS NULL", name: "idx_claim_queries_open_to", algorithm: :concurrently, if_not_exists: true
    add_index :tour_approval_steps, :acted_by_id, where: "acted_by_id IS NOT NULL", algorithm: :concurrently, if_not_exists: true
    add_index :project_budget_line_items, :budget_line_item_id, algorithm: :concurrently, if_not_exists: true
    add_index :project_budget_line_items, :budget_line_item_code_id, algorithm: :concurrently, if_not_exists: true
  end
end
