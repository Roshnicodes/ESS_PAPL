# Employee side of the claim form (TA/DA or Local Mileage), nested under the tour.
class TourClaimsController < ApplicationController
  before_action :set_tour
  before_action :set_claim, except: %i[new create]
  before_action :block_closed_local_month, only: %i[new create edit update]

  def new
    if (existing = @tour.tour_claim)
      return redirect_to edit_tour_claim_path(@tour) if existing.maker_editable?
      return redirect_to tour_claim_path(@tour)
    end
    @claim = TourClaim.build_for(@tour)
    authorize! :create, @claim
    unless @tour.claimable?
      return redirect_to @tour, alert: @tour.approved? ? "Claim form opens on #{@tour.claim_open_on.strftime('%d/%m/%Y')} (after tour To-Date)." : "Claim form is available only after the tour is approved."
    end
    seed_rows
    render :edit
  end

  def create
    @claim = TourClaim.build_for(@tour)
    authorize! :create, @claim
    # the form already posts the pre-filled day rows – don't keep the server-side copies too
    @claim.claim_visit_reports = [] if params.dig(:tour_claim, :claim_visit_reports_attributes).present?
    @claim.assign_attributes(claim_params)
    save_and_maybe_submit
  end

  def edit
    authorize! :update, @claim
    seed_rows
  end

  def update
    authorize! :update, @claim
    return resend_corrected if @claim.needs_reapproval_on_edit?
    @claim.assign_attributes(claim_params)
    save_and_maybe_submit
  end

  # Print / view
  def show
    authorize! :read, @claim
    @logs = @claim.activity_logs.includes(:actor)
  end

  private

  # A claim that is already with an approver (or approved) has no draft to go back to:
  # any correction clears the approvals and starts again from L1.
  def resend_corrected
    @claim.edit_and_resend!(claim_params, by: current_user)
    redirect_to tours_path(type: @tour.tour_type),
      notice: "Claim corrected and sent again to L1 – #{@claim.l1_approver} for approval."
  rescue ActiveRecord::RecordInvalid
    seed_rows
    render :edit, status: :unprocessable_entity
  end

  def save_and_maybe_submit
    TourClaim.transaction do
      @claim.submitting = params[:commit_action] == "submit"
      @claim.save!
      @claim.submit!(by: current_user) if @claim.submitting?
    end
    redirect_to tours_path(type: @tour.tour_type),
      notice: @claim.submitting? ? "Claim sent to L1 – #{@claim.l1_approver}." : "Claim form saved."
  rescue ActiveRecord::RecordInvalid
    seed_rows
    render :edit, status: :unprocessable_entity
  end

  # A Local Mileage month closes on the cutoff day of the next month (PD HR sets it,
  # globally or per employee). After that the employee can neither fill nor send that
  # month's claim – e.g. with cutoff day 5, an October claim is dead from 06-Nov.
  # Claims already with an approver are untouched: only the employee's own window closes.
  def block_closed_local_month
    return unless @tour.type_local? && @tour.claim_month
    return if current_user.admin?   # admin may still correct an old month
    return if @claim && !@claim.maker_editable?
    period = LocalMileagePeriod.new(@tour.user)
    return unless period.closed?(@tour.claim_month)
    redirect_to tours_path(type: "local"), alert: period.closed_message(@tour.claim_month)
  end

  def set_tour
    @tour = current_user.tours.find(params[:tour_id])
  rescue ActiveRecord::RecordNotFound
    @tour = Tour.accessible_by(current_ability).find(params[:tour_id])
  end

  def set_claim
    @claim = TourClaim.with_lines.find_by(tour_id: @tour.id) or raise ActiveRecord::RecordNotFound
    @claim.tour = @tour
  end

  def seed_rows
    # Empty starter rows are rejected on save, so they never create a zero-value
    # expense by themselves.
    associations = if @claim.type_local?
      %i[claim_local_travels]
    else
      %i[claim_city_travels claim_local_travels claim_lodgings claim_daily_allowances claim_incidentals]
    end

    associations.each do |association|
      lines = @claim.public_send(association)
      lines.build if lines.empty?
    end

    @claim.seed_daily_visit_reports
  end

  LINE_AMOUNTS = %i[id position amount _destroy].freeze

  def claim_params
    params.require(:tour_claim).permit(:bank_account_id, 
      :general_description, :advance_amount, :helmet_declaration,
      claim_city_travels_attributes: LINE_AMOUNTS + %i[travel_date departure_city arrival_city travel_mode_id ticket_quota bill_ticket_no remark],
      claim_local_travels_attributes: LINE_AMOUNTS + %i[travel_date place_from place_to travel_mode_id meter_from meter_to kilometers purpose],
      claim_lodgings_attributes: LINE_AMOUNTS + %i[lodging_date city_id place_name from_date to_date no_of_days rate remark],
      claim_daily_allowances_attributes: LINE_AMOUNTS + %i[departure_city departure_at city_id arrival_city_name arrival_at no_of_days da_rate applicable_percent],
      claim_incidentals_attributes: LINE_AMOUNTS + %i[expense_date particular bill_no],
      claim_visit_reports_attributes: %i[id position visit_date place_visited tasks_accomplished action_points time_frame remark _destroy]
    )
  end
end
