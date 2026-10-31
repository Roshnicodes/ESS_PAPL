# Mode of Travel master (PD HR / PD Finance): add, edit, enable/disable, per-km rate.
#   Tour modes  -> ₹0 per km (amount typed in claim)
#   Local modes -> ₹/km; rate > 0 means KM × rate, rate 0 means KM and total typed (e.g. Public Transport)
class Masters::TravelModesController < ApplicationController
  load_and_authorize_resource

  def index
    @travel_modes = TravelMode.ordered.includes(:mileage_rates, mode_approvers: :user)
  end

  def new
    @travel_mode.assign_attributes(active: true, for_tour_plan: true, for_city_travel: true, position: TravelMode.maximum(:position).to_i + 1)
  end

  def edit; end

  def create
    @travel_mode.created_by = @travel_mode.updated_by = current_user
    save_with_rate(:master_created)
  end

  def update
    @travel_mode.assign_attributes(travel_mode_params.merge(updated_by: current_user))
    save_with_rate(:master_updated)
  end

  def toggle
    @travel_mode.update!(active: !@travel_mode.active?, updated_by: current_user)
    @travel_mode.log_activity!(@travel_mode.active? ? :mode_enabled : :mode_disabled)
    redirect_to masters_travel_modes_path, notice: "#{@travel_mode.name} #{@travel_mode.active? ? 'enabled' : 'disabled'}."
  end

  private

  def save_with_rate(action)
    rate = params.dig(:travel_mode, :rate_per_km).presence&.to_d
    rate = nil unless @travel_mode.for_local_travel? && can?(:create, MileageRate)
    if rate
      @travel_mode.km_based     = rate.positive?
      @travel_mode.manual_total = !rate.positive?
    elsif !@travel_mode.for_local_travel?
      @travel_mode.km_based = @travel_mode.manual_total = false
    end
    changes = @travel_mode.changes.except("updated_by_id", "created_by_id")

    TravelMode.transaction do
      @travel_mode.save!
      if rate&.positive? && rate != @travel_mode.current_rate
        @travel_mode.mileage_rates.create!(rate_per_km: rate, effective_from: Date.current, created_by: current_user,
                                           remark: "Set from Mode of Travel master")
      end
      if params.key?(:approver_ids) || params.key?(:notify_ids)
        before = [ @travel_mode.approver_chain.map(&:user_id), @travel_mode.watchers.map(&:user_id).sort, @travel_mode.tatkal_chain.map(&:user_id) ]
        @travel_mode.set_approvers!(Array(params[:approver_ids]), Array(params[:notify_ids]), @travel_mode.is_train? ? Array(params[:tatkal_ids]) : [])
        after = [ @travel_mode.approver_chain.map(&:user_id), @travel_mode.watchers.map(&:user_id).sort, @travel_mode.tatkal_chain.map(&:user_id) ]
        changes["extra_approvers"] = [ before[0], after[0] ] if before[0] != after[0]
        changes["notify"] = [ before[1], after[1] ] if before[1] != after[1]
        changes["tatkal_approvers"] = [ before[2], after[2] ] if before[2] != after[2]
      end
      @travel_mode.log_activity!(action, details: changes) if changes.any?
    end
    redirect_to masters_travel_modes_path, notice: "#{@travel_mode.name} saved."
  rescue ActiveRecord::RecordInvalid => e
    @travel_mode.errors.add(:base, e.record.errors.full_messages.to_sentence) unless e.record == @travel_mode
    render(@travel_mode.persisted? ? :edit : :new, status: :unprocessable_entity)
  end

  def travel_mode_params
    params.require(:travel_mode).permit(:name, :category, :for_tour_plan, :for_city_travel, :for_local_travel, :position, :active, :is_train)
  end
end
