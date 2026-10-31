# E. Incidental expenses (misc / meeting / others)
class ClaimIncidental < ApplicationRecord
  include ClaimLine
  validates :expense_date, :particular, presence: true
end
