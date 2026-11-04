# A. Travel city to city (start and end at headquarter)
class ClaimCityTravel < ApplicationRecord
  include ClaimLine
  belongs_to :travel_mode

  validates :travel_date, presence: true
  validates :departure_city, :arrival_city, presence: true, unless: :no_travel?
  validates :ticket_quota, inclusion: { in: TourVisit::QUOTAS.values }
  before_validation { self.ticket_quota = "normal" unless travel_mode&.is_train? }   # quota only for trains

  def tatkal? = ticket_quota == "tatkal"
  def no_travel? = travel_mode&.no_travel?

  private

  # NA: no journey, so no ticket and no amount
  def compute_amount
    super if defined?(super)
    return unless no_travel?
    self.amount = self.deduction_amount = 0
    self.departure_city = departure_city.to_s
    self.arrival_city = arrival_city.to_s
  end
end
