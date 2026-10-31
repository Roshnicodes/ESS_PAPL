# Finance can send a claim back to L1 / L2 with a question; that person replies (remark) and it returns to Finance.
class CreateClaimQueries < ActiveRecord::Migration[8.1]
  STATUSES = %w[draft submitted l1_approved finance_pending finance_query approved returned rejected cancelled].freeze

  def change
    create_table :claim_queries do |t|
      t.references :tour_claim, null: false, foreign_key: true, index: false
      t.references :asked_by, null: false, foreign_key: { to_table: :users }, index: false
      t.references :asked_to, null: false, foreign_key: { to_table: :users }, index: true
      t.string   :asked_to_role, null: false, limit: 10            # l1 | l2
      t.text     :question, null: false
      t.text     :answer
      t.datetime :answered_at
      t.timestamps
    end
    add_index :claim_queries, [ :tour_claim_id, :created_at ], name: "idx_claim_queries_claim"
    # only one open question per claim at a time
    add_index :claim_queries, :tour_claim_id, unique: true, where: "answered_at IS NULL", name: "uniq_claim_queries_open"
    add_check_constraint :claim_queries, "asked_to_role IN ('l1','l2')", name: "chk_claim_queries_role"
    add_check_constraint :claim_queries, "length(btrim(question)) > 0", name: "chk_claim_queries_question"
    add_check_constraint :claim_queries, "answered_at IS NULL OR length(btrim(coalesce(answer, ''))) > 0", name: "chk_claim_queries_answer"

    add_check_constraint :tour_claims, "status IN (#{STATUSES.map { |s| "'#{s}'" }.join(',')})", name: "chk_tour_claims_status"
  end
end
