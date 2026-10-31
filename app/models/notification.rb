class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true

  # every bell notification is also mailed (through krai) when ESS_MAIL_RELAY_URL is set
  after_create_commit { EssMailRelay.notify(self) }

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def read? = read_at.present?
  def mark_read! = (update_column(:read_at, Time.current) unless read?)
end
