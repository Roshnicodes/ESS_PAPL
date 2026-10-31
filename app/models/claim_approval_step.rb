# Extra approval of a TA/DA claim after L1 → L2 (e.g. COO, Director) – same rules as the tour plan.
class ClaimApprovalStep < ApplicationRecord
  belongs_to :tour_claim
  belongs_to :approver, class_name: "User"
  belongs_to :acted_by, class_name: "User", optional: true

  def label = approver.designation.presence || approver.name   # shown by designation (COO, Director)
  def done? = acted_at.present?
end
