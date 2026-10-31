class ExpandFinanceMasterNameLengths < ActiveRecord::Migration[8.1]
  def change
    # The supplied BLI sheet includes a few descriptive line items longer than
    # the old 200-character limit. Keep their full finance wording intact.
    change_column :projects, :name, :string, limit: 500
    change_column :budget_line_items, :name, :string, limit: 500
    change_column :budget_line_item_codes, :name, :string, limit: 500
  end
end
