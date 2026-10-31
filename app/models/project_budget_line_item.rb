class ProjectBudgetLineItem < ApplicationRecord
  belongs_to :project
  belongs_to :budget_line_item
  belongs_to :budget_line_item_code
  belongs_to :created_by, class_name: "User", optional: true

  validates :budget_line_item_code_id, uniqueness: { scope: %i[project_id budget_line_item_id] }

  scope :active, -> { where(active: true) }
  scope :for_project, ->(project_id) { active.where(project_id: project_id) }
end
