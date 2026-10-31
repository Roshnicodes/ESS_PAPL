# City master with DA rate – the only cities offered in the claim form (D. DA, C. Lodging).
# Loaded from HR's TA/DA city list (db/data/cities.csv); PD HR adds / edits / disables them.
class City < ApplicationRecord
  include NameMaster
  include Auditable
  validates :da_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :lodging_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true   # not used – lodging uses da_rate

  # DA rate per day (C. Lodging rate is typed by the employee)
  def claim_rate = da_rate
  validates :name, length: { maximum: 100 }
  validates :state, length: { maximum: 60 }
end
