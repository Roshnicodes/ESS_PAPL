class NotificationsAndFinanceApprover < ActiveRecord::Migration[8.1]
  def change
    # In-app notifications (bell). One row per recipient.
    create_table :notifications do |t|
      t.references :user,  null: false, foreign_key: true, index: false          # recipient
      t.references :actor, foreign_key: { to_table: :users }, index: false        # who did it
      t.references :notifiable, polymorphic: true, null: false, index: false      # Tour / TourClaim
      t.string   :kind,  null: false, limit: 40
      t.string   :title, null: false, limit: 200
      t.text     :body
      t.string   :url,   null: false, limit: 300
      t.datetime :read_at
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_index :notifications, [ :user_id, :created_at ], order: { created_at: :desc }
    add_index :notifications, :user_id, where: "read_at IS NULL", name: "idx_notifications_unread"
    add_index :notifications, [ :notifiable_type, :notifiable_id ]

    # Finance person per employee (decided by PD HR); claim's final step goes to this person
    add_reference :users, :finance_approver, foreign_key: { to_table: :users }
    add_reference :tour_claims, :finance_approver, foreign_key: { to_table: :users }, index: false
    add_index :tour_claims, [ :finance_approver_id, :status ]
  end
end
