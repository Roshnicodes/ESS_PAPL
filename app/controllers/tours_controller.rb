class ToursController < ApplicationController
  before_action :set_type, only: %i[index new create]
  load_and_authorize_resource only: %i[show cancel]
  before_action :set_own_editable_tour, only: %i[edit update submit]
  before_action :require_admin, only: :destroy

  # Tour History / Local Mileage History
  def index
    @tours = current_user.tours.where(tour_type: @type)
                         .includes(:approver, :l2_approver, :decided_by, :returned_by, :l1_approved_by, user: :location, tour_claim: %i[approved_by rejected_by l1_approver l2_approver])
                         .includes({ approval_steps: :approver }, activity_logs: :actor, tour_claim: :activity_logs)
                         .newest_first.page(params[:page]).per(20)
    @unread = unread_counts(@tours)
  end

  def new
    authorize! :create, Tour
    return redirect_to(new_local_mileage_path) if @type == "local"
    @tour = current_user.tours.new(tour_type: @type)
    if @tour.type_local?
      @period = LocalMileagePeriod.new(current_user)
      @tour.general_description = "local travel milage claim"   # live ESS default
    end   # tour dates start empty – employee picks them
    @tour.tour_visits.build if @tour.tour_visits.empty?   # one row; more via Add
  end

  def create
    authorize! :create, Tour
    @tour = current_user.tours.new(tour_params.merge(tour_type: @type, send_now: params[:commit_action] == "send"))
    if @tour.save
      if @tour.type_local?
        redirect_to new_tour_claim_path(@tour), notice: "Local Milage Claim for #{@tour.claim_month.strftime('%m-%Y')} – fill B. Local Travel."
      elsif @tour.draft?
        redirect_to tours_path, notice: "Tour plan saved. Use “Send for Approval” when ready."
      else
        redirect_to @tour, notice: "Tour plan sent to L1 – #{@tour.approver} for approval."
      end
    else
      render_form_again(:new)
    end
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.cause.is_a?(PG::ExclusionViolation) || e.cause.is_a?(PG::UniqueViolation)
    @tour.errors.add(:base, "These dates clash with another live tour/claim of yours.")
    render_form_again(:new)
  end

  def edit
    @tour.tour_visits.build if @tour.tour_visits.empty?
  end

  # Save again, or Save & Send (admin: correct any tour, status unchanged)
  def update
    if @admin_edit
      @tour.admin_update!(tour_params, by: current_user, remark: params[:admin_remark])
      return redirect_to(@tour, notice: "Tour plan updated by admin.")
    end
    if @tour.needs_reapproval_on_edit?   # pending / approved tour edited by the employee → back to L1
      was = @tour.status
      @tour.edit_and_resend!(tour_params, by: current_user)
      return redirect_to(@tour, notice: @tour.submitted_at_previously_changed? || was != @tour.status ?
        "Tour plan updated and sent again to L1 – #{@tour.approver} for approval." : "No change made.")
    end
    Tour.transaction do
      @tour.assign_attributes(tour_params)
      @tour.save!
      @tour.submit!(by: current_user) if params[:commit_action] == "send"
    end
    redirect_to(@tour.draft? ? tours_path : @tour,
                notice: @tour.draft? ? "Tour plan saved." : "Tour plan sent to L1 – #{@tour.approver} for approval.")
  rescue ActiveRecord::RecordInvalid
    render_form_again(:edit)
  end

  # Send a saved draft
  def submit
    @tour.submit!(by: current_user)
    redirect_to @tour, notice: "Tour plan sent to L1 – #{@tour.approver} for approval."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_tour_path(@tour), alert: e.record.errors.full_messages.to_sentence
  end

  # Admin: soft delete with remark (kept in audit, hidden everywhere)
  def destroy
    tour = Tour.find(params[:id])
    tour.admin_delete!(by: current_user, remark: params[:delete_remark])
    redirect_to masters_all_tours_path, notice: "Tour plan deleted."
  end

  def show
    @logs = @tour.activity_logs.includes(:actor)
    @claim_logs = @tour.tour_claim&.activity_logs&.includes(:actor) || []
    mark_tour_notifications_read if @tour.user_id == current_user.id
  end

  def cancel
    @tour.cancel!(by: current_user, remark: params[:cancel_remark])
    redirect_to tours_path(type: @tour.tour_type), notice: "#{@tour.type_local? ? 'Local mileage claim' : 'Tour plan'} cancelled."
  end

  private

  # Opening the tour page = employee has seen its updates (clears the red badge)
  def mark_tour_notifications_read
    scope = current_user.notifications.unread
    scope.where(notifiable: @tour)
         .or(scope.where(notifiable_type: "TourClaim", notifiable_id: TourClaim.where(tour_id: @tour.id).select(:id)))
         .update_all(read_at: Time.current)
  end

  # tour_id => unread notification count (tour + its claim) for the red badge
  def unread_counts(tours)
    ids = tours.map(&:id)
    claim_to_tour = TourClaim.where(tour_id: ids).pluck(:id, :tour_id).to_h
    current_user.notifications.unread
                .where(notifiable_type: "Tour", notifiable_id: ids)
                .or(current_user.notifications.unread.where(notifiable_type: "TourClaim", notifiable_id: claim_to_tour.keys))
                .pluck(:notifiable_type, :notifiable_id)
                .each_with_object(Hash.new(0)) { |(type, id), h| h[type == "Tour" ? id : claim_to_tour[id]] += 1 }
  end

  def render_form_again(view)
    @period = LocalMileagePeriod.new(current_user) if @tour.type_local?
    @tour.tour_visits.build if @tour.tour_visits.reject(&:marked_for_destruction?).empty?
    render view, status: :unprocessable_entity
  end

  def set_type
    @type = params[:type].to_s == "local" ? "local" : "tour"
  end

  def set_own_editable_tour
    own = current_user.tours.type_tour.find_by(id: params[:id])
    if own && (action_name == "submit" ? own.editable? : own.maker_editable?)
      @tour = own
    elsif current_user.admin?
      @tour = Tour.find(params[:id])
      @admin_edit = true
      raise Workflow::NotAllowed, "Use Send from the tour page" if action_name == "submit"
    else
      raise Workflow::NotAllowed, "This tour cannot be edited – its claim is already made"
    end
    @type = @tour.tour_type
  end

  def require_admin
    raise CanCan::AccessDenied, "Only admin can delete" unless current_user.admin?
  end

  def tour_params
    params.require(:tour).permit(:from_date, :to_date, :general_description,
      tour_visits_attributes: %i[id visit_date place travel_mode_id ticket_quota planned_activity position _destroy])
  end
end
