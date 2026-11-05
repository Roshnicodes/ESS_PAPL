# One employee told about an IOM / Circular (only for "selected employees").
class CircularRecipient < ApplicationRecord
  belongs_to :circular
  belongs_to :user

  validates :user_id, uniqueness: { scope: :circular_id }
end
