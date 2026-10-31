# Per-km rate history. Only PD Finance creates rows; rows are never edited so old claims stay explainable.
class MileageRate < ApplicationRecord
  belongs_to :travel_mode
  belongs_to :created_by, class_name: "User"

  validates :rate_per_km, presence: true, numericality: { greater_than_or_equal_to: 0, less_than: 1000 }
  validates :effective_from, presence: true, uniqueness: { scope: :travel_mode_id, message: "already has a rate for this date" }
  validate  :travel_mode_is_km_based

  after_create :audit

  def readonly? = !new_record? || super

  private

  def travel_mode_is_km_based
    errors.add(:travel_mode, "is not kilometre based") if travel_mode && !travel_mode.km_based?
  end

  def audit
    travel_mode.log_activity!(:rate_changed, actor: created_by, remark: remark,
      details: { rate_per_km: rate_per_km.to_s, effective_from: effective_from.to_s })
  end
end
