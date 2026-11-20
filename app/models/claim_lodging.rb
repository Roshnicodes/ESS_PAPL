# C. Lodging / stay expenses
class ClaimLodging < ApplicationRecord
  include ClaimLine
  belongs_to :city, optional: true

  validates :from_date, :to_date, presence: true
  validates :no_of_days, :rate, numericality: { greater_than_or_equal_to: 0 }
  # the employee types No of days and Lodging Rate; Amount = days × rate (not typed)
  validates :no_of_days, numericality: { greater_than: 0, message: "– enter the number of days" }, if: :employee_filling?
  validates :rate, numericality: { greater_than: 0, message: "– enter the lodging rate per day" }, if: :employee_filling?
  before_validation { self.rate ||= 0; self.no_of_days ||= 0 }
  validate  :place_given
  validate  :date_order

  def place_label = city && city.name != "Other" ? city.name : place_name

  private

  # Amount = No of days × rate while the employee fills the claim. Once sent, reviewers only add
  # deductions, so the amount of a sent claim is never worked out again.
  def compute_amount
    return unless employee_filling?
    self.amount = (no_of_days.to_d * rate.to_d).round(2)
  end

  def employee_filling? = tour_claim.nil? || tour_claim.employee_editable?

  def place_given
    errors.add(:base, "Lodging: select a city or enter the place") if city.nil? && place_name.blank?
  end

  def date_order
    errors.add(:to_date, "must be after From date-time") if from_date && to_date && to_date < from_date
  end
end
