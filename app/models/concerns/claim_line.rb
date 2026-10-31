# Shared amount logic for claim sections A–E: total = amount - deduction.
module ClaimLine
  extend ActiveSupport::Concern

  included do
    belongs_to :tour_claim

    validates :amount, :deduction_amount, numericality: { greater_than_or_equal_to: 0 }
    validates :deduction_remark, length: { maximum: 255 }
    validate  :deduction_within_amount
    validate  :deduction_needs_remark

    before_validation :compute_total
  end

  private

  def compute_amount
    # sections override when amount is derived (km x rate, days x rate)
  end

  def compute_total
    compute_amount
    self.amount           = (amount || 0).to_d.round(2)
    self.deduction_amount = (deduction_amount || 0).to_d.round(2)
    self.total_amount     = amount - deduction_amount
  end

  def deduction_within_amount
    errors.add(:deduction_amount, "cannot exceed amount") if deduction_amount.to_d > amount.to_d
  end

  def deduction_needs_remark
    errors.add(:deduction_remark, "is required when deducting") if deduction_amount.to_d.positive? && deduction_remark.blank?
  end
end
