class BudgetLineItemCode < ApplicationRecord
  include NameMaster
  belongs_to :created_by, class_name: "User", optional: true
  has_many :tour_claims, dependent: :restrict_with_error
  has_many :project_budget_line_items, dependent: :restrict_with_error
end
