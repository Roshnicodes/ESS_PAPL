# Small key/value settings an admin can change from the app (e.g. IT Tools single sign-on secrets).
# Values marked secret are stored encrypted.
class CreateAppSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :app_settings do |t|
      t.string :key, null: false, limit: 100
      t.text   :value
      t.references :updated_by, foreign_key: { to_table: :users }, index: false
      t.timestamps
    end
    add_index :app_settings, :key, unique: true
  end
end
