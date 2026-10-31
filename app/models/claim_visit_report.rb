# Brief detail of travel – tasks accomplished per visit
class ClaimVisitReport < ApplicationRecord
  belongs_to :tour_claim
  belongs_to :tour_visit, optional: true
  validates :visit_date, :place_visited, presence: true
  validates :tasks_accomplished, length: { maximum: 2000 }
  validates :remark, length: { maximum: 500 }
end
