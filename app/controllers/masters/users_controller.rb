# PD HR: Employee List – maintained by uploading HR's Excel (download / upload).
class Masters::UsersController < ApplicationController
  load_and_authorize_resource except: %i[export import]

  def index
    @users = User.includes(:location, :reporting_manager, :l2_manager, :finance_approver).order(:name)
    @users = search(@users, params[:q]) if params[:q].present?
    @users = @users.page(params[:page]).per(30)
  end

  # Download Excel (same columns as HR's sheet – edit and upload back)
  def export
    authorize! :export, User
    send_data EmployeeExport.new(User.where.not(emp_code: "ADMIN").order(:name)).to_xlsx,
              filename: "employee_list_#{Date.current}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  # Upload Excel – existing employees stay unchanged (unless "update existing" is ticked), new ones are added
  def import
    authorize! :import, User
    file = params[:file]
    return redirect_to(masters_users_path, alert: "Choose an Excel file (.xlsx or .csv) to upload.") if file.blank?
    unless File.extname(file.original_filename).downcase.in?(%w[.xlsx .csv])
      return redirect_to(masters_users_path, alert: "Only .xlsx or .csv files can be uploaded.")
    end
    mode = params[:update_existing] == "1" ? :update : :add_only
    @result = EmployeeImport.new(file.tempfile.path, by: current_user, mode: mode, original_filename: file.original_filename).call
    note = "Sheet “#{@result.sheet}”: #{@result.created} new added, #{@result.updated} updated, #{@result.skipped} already existed (unchanged), L1/L2 set for #{@result.managers_linked}."
    note += " Password set for #{@result.passwords} employee#{"s" unless @result.passwords == 1}." if @result.passwords.positive?
    flash[:notice] = note
    flash[:import_errors] = @result.errors.first(5).map { |e| e.to_s.truncate(100) } if @result.errors.any?
    redirect_to masters_users_path
  rescue ArgumentError, Zip::Error => e
    redirect_to masters_users_path, alert: "Could not read the file: #{e.message}"
  end

  def new; end
  def edit; end

  def create
    if @user.save
      @user.log_activity!(:user_created)
      redirect_to masters_users_path, notice: "Employee #{@user.emp_code} created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    attrs = user_params
    attrs = attrs.except(:password, :password_confirmation) if attrs[:password].blank?
    @user.assign_attributes(attrs)
    changes = @user.changes.except("encrypted_password")
    if @user.save
      @user.log_activity!(:user_updated, details: changes) if changes.any?
      redirect_to masters_users_path, notice: "Employee #{@user.emp_code} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Search anything shown in the list: name, code, email, mobile, designation, department, branch, level, role,
  # location, L1 / L2 / Finance name or code. Each word must match some field ("bhopal project" = both).
  SEARCH_SQL = <<~SQL.squish.freeze
    concat_ws(' ', users.name, users.emp_code, users.email, users.mobile, users.designation, users.short_designation,
      users.department, users.branch, users.sub_branch, users.level, users.role, replace(users.role, '_', ' '),
      CASE WHEN users.active THEN 'active' ELSE 'inactive locked' END,
      search_loc.name, search_l1.name, search_l1.emp_code, search_l2.name, search_l2.emp_code, search_fin.name, search_fin.emp_code)
  SQL

  def search(scope, query)
    scope = scope.joins("LEFT JOIN locations search_loc ON search_loc.id = users.location_id")
                 .joins("LEFT JOIN users search_l1 ON search_l1.id = users.reporting_manager_id")
                 .joins("LEFT JOIN users search_l2 ON search_l2.id = users.l2_manager_id")
                 .joins("LEFT JOIN users search_fin ON search_fin.id = users.finance_approver_id")
    query.to_s.split.first(6).reduce(scope) do |s, word|
      s.where("#{SEARCH_SQL} ILIKE ?", "%#{User.sanitize_sql_like(word)}%")
    end
  end

  def user_params
    allowed = %i[emp_code name email designation short_designation level mobile department branch sub_branch date_of_joining
                 location_id reporting_manager_id l2_manager_id finance_approver_id active password password_confirmation]
    allowed << :role if current_user.admin?
    params.require(:user).permit(*allowed)
  end
end
