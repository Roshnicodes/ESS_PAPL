# Extra people for tours using a travel mode: "approve" = must approve in order (after L1 → L2),
# "notify" = only gets a notification (e.g. Administration for Personal Four Wheeler).
class TravelModeApprover < ApplicationRecord
  KINDS = %w[approve notify tatkal].freeze   # tatkal = must approve a Tatkal train booking

  belongs_to :travel_mode
  belongs_to :user

  validates :kind, inclusion: { in: KINDS }
  validates :user_id, uniqueness: { scope: %i[travel_mode_id kind] }

  scope :approvers, -> { where(kind: "approve").order(:position) }
  scope :watchers,  -> { where(kind: "notify") }
end
