# Finance's question to L1 / L2 on a claim, and their reply (both with exact time).
class ClaimQuery < ApplicationRecord
  ROLES = %w[l1 l2].freeze

  belongs_to :tour_claim
  belongs_to :asked_by, class_name: "User"
  belongs_to :asked_to, class_name: "User"

  validates :asked_to_role, inclusion: { in: ROLES }
  validates :question, presence: true, length: { maximum: 2000 }
  validates :answer, length: { maximum: 2000 }

  scope :open, -> { where(answered_at: nil) }
  def open? = answered_at.nil?
  def role_label = asked_to_role.upcase
end
