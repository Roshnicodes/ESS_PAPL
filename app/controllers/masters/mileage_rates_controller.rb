# PD Finance: per km rate. Every change is a new dated row (history kept).
class Masters::MileageRatesController < ApplicationController
  def index
    authorize! :read, MileageRate
    @modes = TravelMode.where(km_based: true).ordered.includes(mileage_rates: :created_by)
    @rate  = MileageRate.new(effective_from: Date.current)
  end

  def create
    @rate = MileageRate.new(params.require(:mileage_rate).permit(:travel_mode_id, :rate_per_km, :effective_from, :remark))
    @rate.created_by = current_user
    authorize! :create, @rate
    if @rate.save
      redirect_to masters_mileage_rates_path, notice: "Rate for #{@rate.travel_mode} set to ₹#{@rate.rate_per_km}/km from #{@rate.effective_from.strftime('%d/%m/%Y')}."
    else
      @modes = TravelMode.where(km_based: true).ordered.includes(mileage_rates: :created_by)
      render :index, status: :unprocessable_entity
    end
  end
end
