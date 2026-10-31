# D. Daily allowance: amount = days x DA rate x applicable %
class ClaimDailyAllowance < ApplicationRecord
  include ClaimLine
  PERCENTS = { "100%" => 100, "50%" => 50, "25%" => 25, "Not Applicable" => 0 }.freeze

  belongs_to :city, optional: true

  validates :departure_city, :departure_at, :arrival_at, presence: true
  validates :applicable_percent, inclusion: { in: PERCENTS.values }
  validates :no_of_days, :da_rate, numericality: { greater_than_or_equal_to: 0 }
  validate  :time_order

  def arrival_label = city && city.name != "Other" ? city.name : arrival_city_name

  # Days from departure → arrival date-time: every full 24 h = 1 day, the remaining hours count as
  #   up to 6 h = 25 % (¼ day) · above 6 and below 10 h = 50 % (½ day) · 10 h or more = 100 % (1 day)
  def self.days_between(from, to)
    return 0.to_d if from.blank? || to.blank? || to <= from
    hours = (to - from) / 3600.0
    full, rest = hours.divmod(24)
    part = if rest <= 0 then 0
    elsif rest <= 6 then 0.25
    elsif rest < 10 then 0.5
    else 1
    end
    (full + part).to_d
  end

  private

  def compute_amount
    self.no_of_days = self.class.days_between(departure_at, arrival_at) if departure_at && arrival_at
    # rate always from the City master; a sent claim keeps its rate unless the city itself is changed
    self.da_rate = city.da_rate if city&.da_rate && (new_record? || city_id_changed? || da_rate.to_d.zero?)
    self.amount = (no_of_days.to_d * da_rate.to_d * applicable_percent.to_i / 100).round(2)
  end

  def time_order
    errors.add(:arrival_at, "must be after departure") if departure_at && arrival_at && arrival_at < departure_at
  end
end
