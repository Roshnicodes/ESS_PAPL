class LocalKmTwoDecimals < ActiveRecord::Migration[8.1]
  # live ESS stores KM like 12.16 (public transport, typed)
  def change
    change_column :claim_local_travels, :kilometers, :decimal, precision: 9, scale: 2, null: false, default: 0
  end
end
