class CreateTours < ActiveRecord::Migration[8.1]
  def change
    create_table :tours do |t|
      t.string     :reference_no, null: false, limit: 30      # TR-2026-000001 / LM-2026-000001
      t.references :user, null: false, foreign_key: true, index: false
      t.string     :tour_type, null: false, default: "tour", limit: 10   # tour | local
      t.date       :from_date, null: false
      t.date       :to_date,   null: false
      t.date       :claim_month                                # 1st of month, only for local mileage
      t.text       :general_description
      t.string     :status, null: false, default: "submitted", limit: 15

      # approval
      t.references :approver, null: false, foreign_key: { to_table: :users }, index: false  # who must act
      t.datetime   :submitted_at, null: false
      t.datetime   :approved_at
      t.datetime   :rejected_at
      t.references :decided_by, foreign_key: { to_table: :users }
      t.text       :decision_remark

      # cancellation (employee, before or after approval)
      t.datetime   :cancelled_at
      t.references :cancelled_by, foreign_key: { to_table: :users }
      t.text       :cancel_remark
      t.string     :status_before_cancel, limit: 15

      t.integer    :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :tours, :reference_no, unique: true
    add_index :tours, [ :user_id, :tour_type, :status ]
    add_index :tours, [ :user_id, :from_date ], order: { from_date: :desc }
    add_index :tours, [ :approver_id, :status ]
    add_index :tours, [ :status, :from_date, :to_date ]          # "currently on tour" lists
    add_index :tours, [ :user_id, :claim_month ], unique: true,
              where: "tour_type = 'local' AND status IN ('submitted','approved')",
              name: "idx_tours_one_live_local_claim_per_month"

    add_check_constraint :tours, "tour_type IN ('tour','local')", name: "chk_tours_type"
    add_check_constraint :tours, "status IN ('submitted','approved','rejected','cancelled')", name: "chk_tours_status"
    add_check_constraint :tours, "to_date >= from_date", name: "chk_tours_date_order"
    add_check_constraint :tours, "tour_type <> 'local' OR claim_month IS NOT NULL", name: "chk_tours_local_month"
    add_check_constraint :tours, "status <> 'approved' OR approved_at IS NOT NULL", name: "chk_tours_approved_at"
    add_check_constraint :tours, "status <> 'rejected' OR rejected_at IS NOT NULL", name: "chk_tours_rejected_at"
    add_check_constraint :tours,
      "status <> 'cancelled' OR (cancelled_at IS NOT NULL AND cancel_remark IS NOT NULL AND length(btrim(cancel_remark)) > 0)",
      name: "chk_tours_cancel_needs_remark"

    # Same employee cannot have two live outstation tours with overlapping dates.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE tours ADD CONSTRAINT excl_tours_no_overlap
          EXCLUDE USING gist (user_id WITH =, daterange(from_date, to_date, '[]') WITH &&)
          WHERE (tour_type = 'tour' AND status IN ('submitted','approved'));
        SQL
      end
      dir.down { execute "ALTER TABLE tours DROP CONSTRAINT IF EXISTS excl_tours_no_overlap" }
    end

    create_table :tour_visits do |t|
      t.references :tour, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer    :position, null: false, default: 0
      t.date       :visit_date, null: false
      t.string     :place, null: false, limit: 200
      t.references :travel_mode, foreign_key: true
      t.text       :planned_activity, null: false
      t.timestamps
    end
    add_index :tour_visits, [ :tour_id, :visit_date, :position ]
  end
end
