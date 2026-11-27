# Special DA rate for some employees by position: a Level, a Designation or one Employee code – in one city or in
# every city. Everyone else keeps the City & DA Rate master rate.
class CreateDaRateRules < ActiveRecord::Migration[8.1]
  def change
    create_table :da_rate_rules do |t|
      t.string  :match_type, limit: 20, null: false          # level / designation / employee
      t.string  :match_value, limit: 150, null: false
      t.references :city, foreign_key: true                  # nil = every city
      t.decimal :da_rate, precision: 10, scale: 2, null: false
      t.boolean :active, null: false, default: true
      t.string  :remark, limit: 255
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_check_constraint :da_rate_rules, "match_type IN ('level', 'designation', 'employee')", name: "chk_da_rate_rules_type"
    add_check_constraint :da_rate_rules, "da_rate >= 0", name: "chk_da_rate_rules_rate"
    add_index :da_rate_rules, "match_type, lower(match_value), COALESCE(city_id, 0)", unique: true, name: "idx_da_rate_rules_unique"
  end
end
