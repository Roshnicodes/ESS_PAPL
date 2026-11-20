# C. Lodging / stay expenses
class ClaimLodging < ApplicationRecord
  include ClaimLine
  belongs_to :city, optional: true

  validates :from_date, :to_date, presence: true
  validates :no_of_days, :rate, numericality: { greater_than_or_equal_to: 0 }
  # the employee types No of days and Amount (the actual stay); rate is optional, for reference
  validates :no_of_days, numericality: { greater_than: 0, message: "– enter the number of days" }, if: :employee_filling?
  validates :amount, numericality: { greater_than: 0, message: "– enter the lodging amount (Rs.)" }, if: :employee_filling?
  before_validation { self.rate ||= 0; self.no_of_days ||= 0 }
  validate  :place_given
  validate  :date_order

  def place_label = city && city.name != "Other" ? city.name : place_name

  private

  # No of days and Amount are typed by the employee – nothing is worked out here any more, so a saved
  # claim keeps exactly what was filled (reviewers only add deductions).
  def compute_amount; end

  def employee_filling? = tour_claim.nil? || tour_claim.employee_editable?

  def place_given
    errors.add(:base, "Lodging: select a city or enter the place") if city.nil? && place_name.blank?
  end

  def date_order
    errors.add(:to_date, "must be after From date-time") if from_date && to_date && to_date < from_date
  end
end
