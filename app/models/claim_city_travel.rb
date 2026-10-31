# A. Travel city to city (start and end at headquarter)
class ClaimCityTravel < ApplicationRecord
  include ClaimLine
  belongs_to :travel_mode

  validates :travel_date, :departure_city, :arrival_city, presence: true
  validates :ticket_quota, inclusion: { in: TourVisit::QUOTAS.values }
  before_validation { self.ticket_quota = "normal" unless travel_mode&.is_train? }   # quota only for trains

  def tatkal? = ticket_quota == "tatkal"
end
