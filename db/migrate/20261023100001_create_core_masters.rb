class CreateCoreMasters < ActiveRecord::Migration[8.1]
  def change
    enable_extension "btree_gist"   # tour date-range overlap exclusion
    enable_extension "pg_trgm"      # fast ILIKE suggestion search on masters

    create_table :locations do |t|
      t.string  :name, null: false, limit: 100
      t.string  :code, limit: 20
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :locations, "lower(name)", unique: true, name: "idx_locations_lower_name"
    add_index :locations, :code, unique: true, where: "code IS NOT NULL"

    create_table :users do |t|
      ## Devise
      t.string   :emp_code,           null: false, limit: 30
      t.string   :email,              limit: 150
      t.string   :encrypted_password, null: false, default: ""
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.integer  :sign_in_count, null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Profile
      t.string     :name,        null: false, limit: 150
      t.string     :designation, limit: 100
      t.string     :short_designation, limit: 20            # e.g. "AM", "MIS"
      t.string     :level,       limit: 10                  # e.g. "L - 5"
      t.string     :mobile,      limit: 15
      t.references :location,          foreign_key: true
      t.references :reporting_manager, foreign_key: { to_table: :users }  # tour + claim approver
      t.references :claim_verifier,    foreign_key: { to_table: :users }  # MIS verification of claim
      t.string     :role,   null: false, default: "employee", limit: 20
      t.boolean    :active, null: false, default: true
      t.timestamps
    end
    add_index :users, "lower(emp_code)", unique: true, name: "idx_users_lower_emp_code"
    add_index :users, "lower(email)", unique: true, where: "email IS NOT NULL", name: "idx_users_lower_email"
    add_index :users, :reset_password_token, unique: true
    add_index :users, [ :role, :active ]
    add_index :users, :name, using: :gin, opclass: :gin_trgm_ops
    add_check_constraint :users, "role IN ('employee','mis','pd_hr','pd_finance','admin')", name: "chk_users_role"
    add_check_constraint :users, "reporting_manager_id IS NULL OR reporting_manager_id <> id", name: "chk_users_not_own_manager"

    # Mode of Travel master (drives every Mode-of-Travel dropdown)
    create_table :travel_modes do |t|
      t.string  :name, null: false, limit: 60
      t.string  :category, null: false, default: "public", limit: 20 # own_vehicle / public / office / none
      t.boolean :km_based,        null: false, default: false         # amount = km x rate
      t.boolean :for_tour_plan,   null: false, default: true
      t.boolean :for_city_travel, null: false, default: true          # claim section A
      t.boolean :for_local_travel, null: false, default: false        # claim section B
      t.integer :position, null: false, default: 0
      t.boolean :active,   null: false, default: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :travel_modes, "lower(name)", unique: true, name: "idx_travel_modes_lower_name"
    add_index :travel_modes, [ :active, :position ]
    add_check_constraint :travel_modes, "category IN ('own_vehicle','public','office','none')", name: "chk_travel_modes_category"

    # Per-km rate history – changed only by PD Finance. Never updated in place: a new row per change.
    create_table :mileage_rates do |t|
      t.references :travel_mode, null: false, foreign_key: true, index: false
      t.decimal    :rate_per_km, null: false, precision: 8, scale: 2
      t.date       :effective_from, null: false
      t.string     :remark, limit: 255
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :mileage_rates, [ :travel_mode_id, :effective_from ], unique: true, order: { effective_from: :desc }
    add_check_constraint :mileage_rates, "rate_per_km >= 0", name: "chk_mileage_rates_positive"

    create_table :cities do |t|
      t.string  :name, null: false, limit: 100
      t.string  :state, limit: 60
      t.decimal :da_rate,      precision: 10, scale: 2   # suggested DA rate
      t.decimal :lodging_rate, precision: 10, scale: 2   # suggested lodging rate
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :cities, "lower(name)", unique: true, name: "idx_cities_lower_name"

    # Finance masters – PD Finance picks (with suggestions) or adds new while approving.
    %i[projects budget_line_items budget_line_item_codes].each do |tbl|
      create_table tbl do |t|
        t.string  :name, null: false, limit: 200
        t.boolean :active, null: false, default: true
        t.references :created_by, foreign_key: { to_table: :users }
        t.timestamps
      end
      add_index tbl, "lower(name)", unique: true, name: "idx_#{tbl}_lower_name"
      add_index tbl, :name, using: :gin, opclass: :gin_trgm_ops, name: "idx_#{tbl}_name_trgm"
    end

    # Local-mileage cutoff day. user_id NULL = rule for all employees; a row per user = override.
    create_table :claim_cutoff_rules do |t|
      t.references :user, foreign_key: true, index: false
      t.integer    :cutoff_day, null: false, limit: 2, default: 5
      t.string     :remark, limit: 255
      t.references :updated_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :claim_cutoff_rules, :user_id, unique: true, where: "user_id IS NOT NULL"
    add_index :claim_cutoff_rules, "(user_id IS NULL)", unique: true, where: "user_id IS NULL", name: "idx_claim_cutoff_rules_single_global"
    add_check_constraint :claim_cutoff_rules, "cutoff_day BETWEEN 1 AND 28", name: "chk_cutoff_day_range"
  end
end
