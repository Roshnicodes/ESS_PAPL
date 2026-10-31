# City & DA Rate master (PD HR): only these cities appear in the claim form; DA is calculated from their rate.
class Masters::CitiesController < ApplicationController
  load_and_authorize_resource
  before_action { authorize! :manage, City }   # everyone may read cities (claim dropdown); only PD HR / admin manage them

  def index
    @cities = City.ordered
    if params[:q].present?
      q = "%#{City.sanitize_sql_like(params[:q].strip)}%"
      @cities = @cities.where("name ILIKE :q OR state ILIKE :q OR CAST(da_rate AS text) ILIKE :q", q: q)
    end
    @cities = @cities.where(active: params[:status] == "active") if params[:status].in?(%w[active inactive])
    @counts = { all: City.count, active: City.active.count }
    @cities = @cities.page(params[:page]).per(50)
    @logs = ActivityLog.where(trackable_type: "City").includes(:actor, :trackable).order(created_at: :desc).limit(40)
  end

  def new
    @city.active = true
  end

  def edit; end

  def create
    if @city.save
      @city.log_activity!(:city_added, details: { da_rate: @city.da_rate.to_s })
      redirect_to masters_cities_path, notice: "#{@city.name} added (DA ₹#{@city.da_rate})."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @city.assign_attributes(city_params)
    changes = @city.changes.except("updated_at").transform_values { |v| v.map(&:to_s) }
    if @city.save
      @city.log_activity!(:city_updated, details: changes) if changes.any?
      redirect_to masters_cities_path, notice: "#{@city.name} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle
    @city.update!(active: !@city.active?)
    @city.log_activity!(@city.active? ? :city_enabled : :city_disabled)
    redirect_back fallback_location: masters_cities_path, notice: "#{@city.name} #{@city.active? ? 'enabled' : 'disabled'}."
  end


  # Download Excel: City, State, DA Rate, Active – fill / change and upload back
  def export
    send_data CityRateExport.new(City.ordered).to_xlsx, filename: "city_da_rates_#{Date.current}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def import
    file = params[:file]
    return redirect_to(masters_cities_path, alert: "Choose the Excel file (.xlsx or .csv) to upload.") if file.blank?
    unless File.extname(file.original_filename).downcase.in?(%w[.xlsx .csv])
      return redirect_to(masters_cities_path, alert: "Only .xlsx or .csv files can be uploaded.")
    end
    res = CityRateImport.new(file.tempfile.path, by: current_user, original_filename: file.original_filename).call
    note = "#{res.created} new cities added, #{res.updated} updated, #{res.unchanged} unchanged."
    note += " #{res.errors.size} row(s) not saved: #{res.errors.first(3).join('; ')}" if res.errors.any?
    redirect_to masters_cities_path, (res.errors.any? ? :alert : :notice) => note
  rescue ArgumentError, Zip::Error, CSV::MalformedCSVError => e
    redirect_to masters_cities_path, alert: "Could not read the file: #{e.message}"
  end

  private

  def city_params
    params.require(:city).permit(:name, :state, :da_rate, :active)
  end
end
