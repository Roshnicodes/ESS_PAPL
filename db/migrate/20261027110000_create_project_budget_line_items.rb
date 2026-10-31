class CreateProjectBudgetLineItems < ActiveRecord::Migration[8.1]
  def change
    # A BLI code is meaningful only inside its project.  Keeping this as a
    # mapping table allows the same BLI or code text to be used by more than
    # one project while making the finance approval dropdowns unambiguous.
    create_table :project_budget_line_items do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.references :budget_line_item, null: false, foreign_key: true, index: false
      t.references :budget_line_item_code, null: false, foreign_key: true, index: false
      t.boolean :active, null: false, default: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :project_budget_line_items,
              %i[project_id budget_line_item_id budget_line_item_code_id],
              unique: true, name: "idx_project_budget_line_item_mapping"
    add_index :project_budget_line_items, %i[project_id active]
  end
end
