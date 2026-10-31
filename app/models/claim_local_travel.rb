# B. Local travel – mirrors the live form:
#   Two / Four Wheeler (km_based): meters → KM = to − from; AMOUNT column shows ₹/km from PD Finance
#                                  master; TOTAL = KM × rate − deduction.
#   Public Transport (manual_total): meters locked at 0, KM and TOTAL typed by employee.
class ClaimLocalTravel < ApplicationRecord
  include ClaimLine
  belongs_to :travel_mode

  validates :travel_date, :place_from, :place_to, presence: true
  validates :kilometers, numericality: { greater_than_or_equal_to: 0, less_than: 10_000 }
  validate  :meter_order
  validate  :manual_mode_needs_ticket_ref

  def km_based? = travel_mode&.km_based?
  def manual?   = travel_mode&.manual_total?

  private

  def compute_amount
    if manual?
      self.meter_from = self.meter_to = nil
      self.rate_per_km = nil
      return
    end
    if meter_from.present? && meter_to.present? && meter_to.to_d >= meter_from.to_d
      self.kilometers = meter_to.to_d - meter_from.to_d
    end
    return unless km_based?
    # rate is (re)snapshotted only while the employee is editing; reviewers keep the snapshot
    self.rate_per_km = travel_mode.rate_on(travel_date || Date.current) if rate_per_km.nil? || tour_claim&.employee_editable?
    self.amount = (kilometers.to_d * rate_per_km.to_d).round(2)
  end

  # Public Transport leaves no meter trail, so the bill / ticket reference is
  # the only proof of the journey.
  def manual_mode_needs_ticket_ref
    return unless manual? && purpose.blank?
    errors.add(:purpose, "/ bill or ticket ref is required for #{travel_mode.name}")
  end

  def meter_order
    if meter_from.present? && meter_to.present? && meter_to.to_d < meter_from.to_d
      errors.add(:meter_to, "must be greater than meter reading from")
    end
    errors.add(:base, "Per km rate is not set for #{travel_mode.name}. Contact PD Finance.") if km_based? && rate_per_km.nil?
  end
end
