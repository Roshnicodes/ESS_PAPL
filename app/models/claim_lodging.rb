# C. Lodging / stay expenses
class ClaimLodging < ApplicationRecord
  include ClaimLine
  belongs_to :city, optional: true

  validates :from_date, :to_date, presence: true
  validates :no_of_days, :rate, numericality: { greater_than_or_equal_to: 0 }
  validate  :place_given
  validate  :date_order

  def place_label = city && city.name != "Other" ? city.name : place_name

  private

  def compute_amount
    # days from From / To date-time, same rule as DA (full 24 h = 1 day; rest ≤6 h 25 %, under 10 h 50 %, 10 h or more 100 %)
    self.no_of_days = ClaimDailyAllowance.days_between(from_date, to_date) if from_date && to_date && to_date >= from_date
    # lodging rate is typed by the employee (only DA comes from the City master)
    self.amount = (no_of_days.to_d * rate.to_d).round(2)
  end

  def place_given
    errors.add(:base, "Lodging: select a city or enter the place") if city.nil? && place_name.blank?
  end

  def date_order
    errors.add(:to_date, "must be after From date-time") if from_date && to_date && to_date < from_date
  end
end
