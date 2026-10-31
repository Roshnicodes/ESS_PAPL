# L1 / L2 tour approval: Approve, Return (to employee) or Reject (final) – remark mandatory for all three.
class Approvals::ToursController < ApplicationController
  before_action :set_pending_tour, only: %i[approve send_back reject]
  before_action -> { redirect_to authenticated_root_path, alert: "Approvals are only for approvers." unless current_user.tour_approver? }, only: %i[index done]

  def index
    @tours = Tour.pending_for(current_user)
                 .includes(:l2_approver, :l3_approver, :l1_approved_by, :l2_approved_by, { approval_steps: :approver }, user: :location, tour_visits: :travel_mode,
                           activity_logs: :actor)
                 .order(:submitted_at)
  end

  # Tour Approval History: everything I forwarded / approved / returned / rejected
  def done
    my_logs = ActivityLog.where(trackable_type: "Tour", actor_id: current_user.id, action: %w[l1_approved l2_approved extra_forwarded approved returned rejected])
    my_logs = my_logs.where(action: params[:action_type]) if params[:action_type].present?
    tour_ids = my_logs.select(:trackable_id)
    @tours = Tour.type_tour.where(id: tour_ids).includes(:user, :approver, :l2_approver)
    if params[:q].present?
      q = "%#{Tour.sanitize_sql_like(params[:q].strip)}%"
      @tours = @tours.joins(:user).where("users.name ILIKE :q OR users.emp_code ILIKE :q", q: q)
    end
    @tours = @tours.order(updated_at: :desc).page(params[:page]).per(30)
    @my_last = ActivityLog.where(trackable_type: "Tour", trackable_id: @tours.map(&:id), actor_id: current_user.id,
                                 action: %w[l1_approved l2_approved extra_forwarded approved returned rejected])
                          .order(:created_at).group_by(&:trackable_id).transform_values(&:last)
  end

  # Full page for one tour (works for 25+ visits); actions only while it is pending with me
  def show
    @tour = Tour.includes(:user, :approver, :l2_approver, :l3_approver, :l1_approved_by, { approval_steps: :approver }, tour_visits: :travel_mode, activity_logs: :actor).find(params[:id])
    authorize! :read, @tour
    @pending = @tour.approvable_by?(current_user)
    queue = Tour.pending_for(current_user).order(:submitted_at).pluck(:id)
    @next_id = queue.reject { |id| id == @tour.id }.first
    @queue_size = queue.size
  end

  def approve
    @tour.approve!(by: current_user, remark: remark!)
    nxt = { "l1_approved" => @tour.l2_approver&.name, "l2_approved" => @tour.l3_label }[@tour.status]   # extra steps by designation
    redirect_to next_or_list, notice: nxt ? "Tour plan forwarded to #{nxt}." : "Tour plan approved."
  end

  def send_back
    @tour.return!(by: current_user, remark: remark!)
    redirect_to next_or_list, notice: "Tour plan returned to #{@tour.user.name} for correction."
  end

  def reject
    @tour.reject!(by: current_user, remark: remark!)
    redirect_to next_or_list, notice: "Tour plan rejected."
  end

  private

  def set_pending_tour
    @tour = Tour.find(params[:id])
    raise CanCan::AccessDenied, "This tour is not pending with you" unless @tour.approvable_by?(current_user)
  end

  # after acting, open the next pending tour (if any) – saves going back to the list
  def next_or_list
    nxt = Tour.pending_for(current_user).order(:submitted_at).first
    nxt ? approvals_tour_path(nxt) : approvals_tours_path
  end

  def remark!
    params[:remark].to_s.strip.presence or raise Workflow::RemarkRequired, "Please write a remark before Approve / Return / Reject."
  end
end
