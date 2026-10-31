class CreateTourClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :tour_claims do |t|
      t.references :tour, null: false, foreign_key: true, index: { unique: true }  # one claim per tour
      t.references :user, null: false, foreign_key: true, index: false            # denormalised for fast lists
      t.string     :claim_type, null: false, limit: 10                             # copy of tour.tour_type
      t.string     :status, null: false, default: "draft", limit: 15

      # Finance coding – mandatory before PD Finance approval
      t.references :project,               foreign_key: true
      t.references :budget_line_item,      foreign_key: true
      t.references :budget_line_item_code, foreign_key: true

      t.text    :general_description
      t.boolean :helmet_declaration, null: false, default: false

      # totals (kept in sync by the model; stored for fast listing/export)
      t.decimal :city_travel_total, null: false, default: 0, precision: 12, scale: 2
      t.decimal :local_travel_total, null: false, default: 0, precision: 12, scale: 2
      t.decimal :lodging_total,     null: false, default: 0, precision: 12, scale: 2
      t.decimal :da_total,          null: false, default: 0, precision: 12, scale: 2
      t.decimal :incidental_total,  null: false, default: 0, precision: 12, scale: 2
      t.decimal :grand_total,       null: false, default: 0, precision: 12, scale: 2
      t.decimal :advance_amount,    null: false, default: 0, precision: 12, scale: 2
      t.decimal :balance_amount,    null: false, default: 0, precision: 12, scale: 2

      # workflow actors + timestamps (every step is ALSO in activity_logs)
      t.references :verifier,    foreign_key: { to_table: :users }, index: false   # MIS
      t.references :recommender, foreign_key: { to_table: :users }, index: false   # reporting manager
      t.datetime   :submitted_at
      t.datetime   :verified_at
      t.references :verified_by,    foreign_key: { to_table: :users }
      t.datetime   :recommended_at
      t.references :recommended_by, foreign_key: { to_table: :users }
      t.datetime   :approved_at
      t.references :approved_by,    foreign_key: { to_table: :users }
      t.datetime   :rejected_at
      t.references :rejected_by,    foreign_key: { to_table: :users }
      t.text       :reject_remark
      t.datetime   :cancelled_at

      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :tour_claims, [ :user_id, :status ]
    add_index :tour_claims, [ :status, :submitted_at ]
    add_index :tour_claims, [ :verifier_id, :status ]
    add_index :tour_claims, [ :recommender_id, :status ]
    add_index :tour_claims, [ :claim_type, :status, :approved_at ]

    add_check_constraint :tour_claims, "claim_type IN ('tour','local')", name: "chk_claims_type"
    add_check_constraint :tour_claims,
      "status IN ('draft','submitted','verified','recommended','approved','rejected','cancelled')", name: "chk_claims_status"
    add_check_constraint :tour_claims,
      "status <> 'approved' OR (project_id IS NOT NULL AND budget_line_item_id IS NOT NULL AND budget_line_item_code_id IS NOT NULL AND approved_at IS NOT NULL)",
      name: "chk_claims_finance_coding_on_approval"
    add_check_constraint :tour_claims, "advance_amount >= 0", name: "chk_claims_advance_positive"

    amounts = lambda do |t|
      t.decimal :amount,           null: false, default: 0, precision: 12, scale: 2
      t.decimal :deduction_amount, null: false, default: 0, precision: 12, scale: 2
      t.string  :deduction_remark, limit: 255
      t.decimal :total_amount,     null: false, default: 0, precision: 12, scale: 2
    end
    amount_checks = lambda do |tbl|
      add_check_constraint tbl, "amount >= 0 AND deduction_amount >= 0 AND deduction_amount <= amount", name: "chk_#{tbl}_amounts"
      add_check_constraint tbl, "total_amount = amount - deduction_amount", name: "chk_#{tbl}_total"
    end

    # A. Travel city-to-city
    create_table :claim_city_travels do |t|
      t.references :tour_claim, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer    :position, null: false, default: 0
      t.date       :travel_date, null: false
      t.string     :departure_city, null: false, limit: 100
      t.string     :arrival_city,   null: false, limit: 100
      t.references :travel_mode, null: false, foreign_key: true
      t.string     :bill_ticket_no, limit: 60
      t.string     :remark, limit: 255
      amounts.call(t)
      t.timestamps
    end
    add_index :claim_city_travels, [ :tour_claim_id, :travel_date ]
    amount_checks.call(:claim_city_travels)

    # B. Local travel (km based – the mileage claim)
    create_table :claim_local_travels do |t|
      t.references :tour_claim, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer    :position, null: false, default: 0
      t.date       :travel_date, null: false
      t.string     :place_from, null: false, limit: 150
      t.string     :place_to,   null: false, limit: 150
      t.references :travel_mode, null: false, foreign_key: true
      t.decimal    :meter_from, precision: 10, scale: 1
      t.decimal    :meter_to,   precision: 10, scale: 1
      t.decimal    :kilometers, null: false, default: 0, precision: 8, scale: 1
      t.decimal    :rate_per_km, precision: 8, scale: 2        # snapshot of rate used
      t.string     :purpose, limit: 255
      amounts.call(t)
      t.timestamps
    end
    add_index :claim_local_travels, [ :tour_claim_id, :travel_date ]
    amount_checks.call(:claim_local_travels)
    add_check_constraint :claim_local_travels, "kilometers >= 0", name: "chk_claim_local_travels_km"
    add_check_constraint :claim_local_travels,
      "meter_from IS NULL OR meter_to IS NULL OR meter_to >= meter_from", name: "chk_claim_local_travels_meter"

    # C. Lodging
    create_table :claim_lodgings do |t|
      t.references :tour_claim, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer    :position, null: false, default: 0
      t.references :city, foreign_key: true
      t.string     :place_name, limit: 150                        # when city = Other
      t.date       :from_date, null: false
      t.date       :to_date,   null: false
      t.decimal    :no_of_days, null: false, default: 0, precision: 5, scale: 1
      t.decimal    :rate,       null: false, default: 0, precision: 10, scale: 2
      t.string     :remark, limit: 255
      amounts.call(t)
      t.timestamps
    end
    add_index :claim_lodgings, [ :tour_claim_id, :from_date ]
    amount_checks.call(:claim_lodgings)
    add_check_constraint :claim_lodgings, "to_date >= from_date", name: "chk_claim_lodgings_dates"

    # D. Daily allowance
    create_table :claim_daily_allowances do |t|
      t.references :tour_claim, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer    :position, null: false, default: 0
      t.string     :departure_city, null: false, limit: 100
      t.datetime   :departure_at, null: false
      t.references :city, foreign_key: true                        # arrival city
      t.string     :arrival_city_name, limit: 150                 # when city = Other
      t.datetime   :arrival_at, null: false
      t.decimal    :no_of_days, null: false, default: 0, precision: 5, scale: 1
      t.decimal    :da_rate,    null: false, default: 0, precision: 10, scale: 2
      t.integer    :applicable_percent, null: false, default: 100, limit: 2
      amounts.call(t)
      t.timestamps
    end
    add_index :claim_daily_allowances, [ :tour_claim_id, :departure_at ]
    amount_checks.call(:claim_daily_allowances)
    add_check_constraint :claim_daily_allowances, "applicable_percent IN (0,25,50,100)", name: "chk_claim_da_percent"
    add_check_constraint :claim_daily_allowances, "arrival_at >= departure_at", name: "chk_claim_da_times"

    # E. Incidental
    create_table :claim_incidentals do |t|
      t.references :tour_claim, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer    :position, null: false, default: 0
      t.date       :expense_date, null: false
      t.string     :particular, null: false, limit: 255
      t.string     :bill_no, limit: 60
      amounts.call(t)
      t.timestamps
    end
    add_index :claim_incidentals, [ :tour_claim_id, :expense_date ]
    amount_checks.call(:claim_incidentals)

    # Brief detail of travel / visit report
    create_table :claim_visit_reports do |t|
      t.references :tour_claim, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer    :position, null: false, default: 0
      t.date       :visit_date, null: false
      t.string     :place_visited, null: false, limit: 200
      t.text       :tasks_accomplished
      t.text       :action_points
      t.string     :time_frame, limit: 100
      t.timestamps
    end
    add_index :claim_visit_reports, [ :tour_claim_id, :visit_date ]
  end
end
