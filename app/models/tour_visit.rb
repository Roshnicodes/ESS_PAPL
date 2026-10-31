class TourVisit < ApplicationRecord
  belongs_to :tour, inverse_of: :tour_visits
  belongs_to :travel_mode, optional: true

  QUOTAS = { "Normal" => "normal", "Tatkal" => "tatkal" }.freeze

  validates :visit_date, :place, :planned_activity, presence: true
  validates :ticket_quota, inclusion: { in: QUOTAS.values }
  before_validation { self.ticket_quota = "normal" unless travel_mode&.is_train? }   # quota only for trains

  def tatkal? = ticket_quota == "tatkal"
  validates :place, length: { maximum: 200 }
  validates :planned_activity, length: { maximum: Tour::ACTIVITY_MAX }

  normalizes :place, with: ->(v) { v.to_s.squish }

  # "Place To Visit" suggestions: places typed before (most used first) + city master.
  def self.place_suggestions(limit: 300)
    typed = group("lower(place)").order(Arel.sql("count(*) DESC")).limit(limit).pluck(Arel.sql("min(place)"))
    (typed + City.active.ordered.pluck(:name)).uniq { _1.downcase }.first(limit + 200)
  end
end
