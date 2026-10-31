# Lodging From / To now carry the time too, so its days are counted from hours (same rule as DA).
class LodgingWithTime < ActiveRecord::Migration[8.1]
  def up
    change_column :claim_lodgings, :from_date, :datetime, null: false
    change_column :claim_lodgings, :to_date, :datetime, null: false
    change_column :claim_lodgings, :no_of_days, :decimal, precision: 6, scale: 2, default: 0, null: false
  end

  def down
    change_column :claim_lodgings, :no_of_days, :decimal, precision: 5, scale: 1, default: 0, null: false
    change_column :claim_lodgings, :to_date, :date, null: false
    change_column :claim_lodgings, :from_date, :date, null: false
  end
end
