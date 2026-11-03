# PD Finance: per km rate. Only the rate is entered – it applies from today until it is changed again
# (earlier rates stay as history). A second change on the same day replaces that day's entry.
class Masters::MileageRatesController < ApplicationController
  def index
    authorize! :read, MileageRate
    @modes = TravelMode.where(km_based: true).ordered.includes(mileage_rates: :created_by)
    @rate  = MileageRate.new(effective_from: Date.current)
  end

  def create
    @rate = MileageRate.new(params.require(:mileage_rate).permit(:travel_mode_id, :rate_per_km, :remark))
    @rate.effective_from = Date.current
    @rate.created_by = current_user
    authorize! :create, @rate
    saved = MileageRate.transaction do
      MileageRate.where(travel_mode_id: @rate.travel_mode_id, effective_from: Date.current).delete_all
      @rate.save or raise ActiveRecord::Rollback   # invalid input: today's earlier entry stays as it was
    end
    if saved
      redirect_to masters_mileage_rates_path, notice: "Rate for #{@rate.travel_mode} set to ₹#{@rate.rate_per_km}/km. It applies until it is changed again."
    else
      @modes = TravelMode.where(km_based: true).ordered.includes(mileage_rates: :created_by)
      render :index, status: :unprocessable_entity
    end
  end
end
