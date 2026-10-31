class CreateActivityLogs < ActiveRecord::Migration[8.1]
  # Append-only audit trail: every action (submit, approve, reject, cancel, claim steps,
  # rate change, cutoff change, master edits) is a row here with exact date-time.
  def change
    create_table :activity_logs do |t|
      t.references :trackable, polymorphic: true, null: false, index: false
      t.references :actor, foreign_key: { to_table: :users }, index: false
      t.string     :action, null: false, limit: 40
      t.string     :from_status, limit: 15
      t.string     :to_status,   limit: 15
      t.text       :remark
      t.jsonb      :details, null: false, default: {}
      t.string     :ip_address, limit: 45
      t.datetime   :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_index :activity_logs, [ :trackable_type, :trackable_id, :created_at ], name: "idx_activity_logs_trackable_time"
    add_index :activity_logs, [ :actor_id, :created_at ]
    add_index :activity_logs, [ :action, :created_at ]

    reversible do |dir|
      dir.up do
        # Make audit rows immutable at the DB level.
        execute <<~SQL
          CREATE FUNCTION activity_logs_immutable() RETURNS trigger AS $$
          BEGIN
            RAISE EXCEPTION 'activity_logs is append-only';
          END;
          $$ LANGUAGE plpgsql;

          CREATE TRIGGER trg_activity_logs_immutable
          BEFORE UPDATE OR DELETE ON activity_logs
          FOR EACH ROW EXECUTE FUNCTION activity_logs_immutable();
        SQL
      end
      dir.down do
        execute "DROP TRIGGER IF EXISTS trg_activity_logs_immutable ON activity_logs"
        execute "DROP FUNCTION IF EXISTS activity_logs_immutable()"
      end
    end
  end
end
