# Employee bank accounts (with passbook copy) – the employee picks one on every claim,
# Finance sees it on the review screen.
class CreateBankAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_accounts do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string  :account_holder_name, null: false, limit: 150
      t.string  :bank_name,           null: false, limit: 100
      t.string  :branch_name,         limit: 100
      t.string  :account_number,      null: false, limit: 20
      t.string  :ifsc_code,           null: false, limit: 11
      t.string  :account_type,        null: false, limit: 10, default: "savings"
      t.boolean :primary,             null: false, default: false
      t.boolean :active,              null: false, default: true
      t.datetime :deleted_at
      t.string  :delete_remark, limit: 500
      t.timestamps
    end

    add_index :bank_accounts, [ :user_id, :active ], where: "deleted_at IS NULL", name: "idx_bank_accounts_user_live"
    add_index :bank_accounts, [ :user_id, :account_number ], unique: true, where: "deleted_at IS NULL", name: "uniq_bank_accounts_user_number"
    add_index :bank_accounts, :user_id, unique: true, where: "\"primary\" AND deleted_at IS NULL", name: "uniq_bank_accounts_one_primary"

    add_check_constraint :bank_accounts, "account_number ~ '^[0-9]{6,20}$'", name: "chk_bank_accounts_number"
    add_check_constraint :bank_accounts, "ifsc_code ~ '^[A-Z]{4}0[A-Z0-9]{6}$'", name: "chk_bank_accounts_ifsc"
    add_check_constraint :bank_accounts, "account_type IN ('savings','current')", name: "chk_bank_accounts_type"

    add_reference :tour_claims, :bank_account, foreign_key: true, index: true
  end
end
