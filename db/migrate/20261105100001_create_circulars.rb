# IOM / Circular published by the administrator: a topic, any number of attachments
# (PDF, Word, Excel, image …) and the employees who are told about it by bell + email.
class CreateCirculars < ActiveRecord::Migration[8.1]
  def change
    create_table :circulars do |t|
      t.string  :topic_type, null: false, limit: 20, default: "circular"
      t.string  :topic,      null: false, limit: 200
      t.text    :description
      t.string  :audience,   null: false, limit: 10, default: "all"
      t.boolean :active,     null: false, default: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }, index: false
      t.datetime :notified_at
      t.integer :notified_count, null: false, default: 0
      t.timestamps
    end
    add_index :circulars, [ :active, :created_at ], order: { created_at: :desc }, name: "idx_circulars_live"
    add_index :circulars, :created_by_id
    add_check_constraint :circulars, "topic_type IN ('iom','circular')", name: "chk_circulars_topic_type"
    add_check_constraint :circulars, "audience IN ('all','selected')", name: "chk_circulars_audience"

    create_table :circular_recipients do |t|
      t.references :circular, null: false, foreign_key: true, index: false
      t.references :user,     null: false, foreign_key: true, index: true
      t.datetime :notified_at
      t.timestamps
    end
    add_index :circular_recipients, [ :circular_id, :user_id ], unique: true, name: "uniq_circular_recipient"
  end
end
