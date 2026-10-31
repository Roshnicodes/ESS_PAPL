# DA days are now counted from departure/arrival time in quarter days (0.25 / 0.5 / 0.75 / 1),
# and the travel report gets an optional remark next to the mandatory "Tasks Accomplished".
class DaQuarterDaysAndReportRemark < ActiveRecord::Migration[8.1]
  def up
    change_column :claim_daily_allowances, :no_of_days, :decimal, precision: 6, scale: 2, default: 0, null: false
    add_column :claim_visit_reports, :remark, :string, limit: 500
  end

  def down
    remove_column :claim_visit_reports, :remark
    change_column :claim_daily_allowances, :no_of_days, :decimal, precision: 5, scale: 1, default: 0, null: false
  end
end
