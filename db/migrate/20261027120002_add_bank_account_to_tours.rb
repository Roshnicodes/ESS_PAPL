# Bank chosen on the Tour Plan – carried into its claim (can still be changed there).
class AddBankAccountToTours < ActiveRecord::Migration[8.1]
  def change
    add_reference :tours, :bank_account, foreign_key: true, index: true
  end
end
