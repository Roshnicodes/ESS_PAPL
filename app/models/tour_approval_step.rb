# One extra approval of a tour after L1 → L2 (L3, L4 …), e.g. COO then Director for Personal Four Wheeler.
class TourApprovalStep < ApplicationRecord
  belongs_to :tour
  belongs_to :approver, class_name: "User"
  belongs_to :acted_by, class_name: "User", optional: true

  def level = "L#{position + 2}"
  def label = approver.designation.presence || approver.name   # shown by designation (COO, Director)
  def done? = acted_at.present?
end
