# Admin-managed project → BLI → code mapping used at PD Finance approval.
class Masters::FinanceCodesController < ApplicationController
  before_action :require_admin

  def index
    @mappings = ProjectBudgetLineItem.includes(:project, :budget_line_item, :budget_line_item_code)
                                     .joins(:project).order("projects.name", "project_budget_line_items.id")
                                     .page(params[:page]).per(50)
    @mapping_count = ProjectBudgetLineItem.active.count
    @project_count = Project.joins(:project_budget_line_items).merge(ProjectBudgetLineItem.active).distinct.count
  end

  def import
    file = params[:file]
    return redirect_to(masters_finance_codes_path, alert: "Choose the BLI CSV file to upload.") if file.blank?
    unless File.extname(file.original_filename).downcase == ".csv"
      return redirect_to(masters_finance_codes_path, alert: "Please upload a CSV file (.csv).")
    end

    result = BudgetLineItemImport.new(file.tempfile.path, by: current_user).call
    flash[:notice] = "BLI list imported: #{result.created} mapping#{'s' unless result.created == 1} added, #{result.existing} already present."
    flash[:import_errors] = result.errors.first(30) if result.errors.any?
    redirect_to masters_finance_codes_path
  rescue ArgumentError => e
    redirect_to masters_finance_codes_path, alert: e.message
  end

  def template
    csv = CSV.generate { |rows| rows << [ "BLI_Name", "BLI Code", "Project_Name" ] }
    send_data csv,
              filename: "bli_upload_template.csv", type: "text/csv", disposition: "attachment"
  end

  private

  def require_admin
    raise CanCan::AccessDenied, "Only an administrator can manage the BLI upload." unless current_user.admin?
  end
end
