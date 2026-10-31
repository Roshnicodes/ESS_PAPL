class ActivityLog < ApplicationRecord
  belongs_to :trackable, polymorphic: true
  belongs_to :actor, class_name: "User", optional: true

  validates :action, presence: true

  scope :chronological, -> { order(:created_at, :id) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def readonly?
    persisted?
  end

  def label
    action.humanize
  end
end
