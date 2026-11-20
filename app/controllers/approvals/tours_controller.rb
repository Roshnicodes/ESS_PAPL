# L1 / L2 tour approval: Approve, Return (to employee) or Reject (final) – remark mandatory for all three.
class Approvals::ToursController < ApplicationController
  include TourDateRange
  include ListSearch
  before_action :set_pending_tour, only: %i[approve send_back reject]
  before_action :set_tour_date_range, only: %i[index done]
  before_action -> { redirect_to authenticated_root_path, alert: "Approvals are only for approvers." unless current_user.tour_approver? }, only: %i[index done]

  def index
    @tours = Tour.pending_for(current_user)
                 .includes(:l2_approver, :l3_approver, :l1_approved_by, :l2_approved_by, { approval_steps: :approver }, user: :location, tour_visits: :travel_mode,
                           activity_logs: :actor)
                 .order(:submitted_at)
    @tours = search_tours(within_tour_dates(@tours))
  end

  # Tour Approval History: everything I forwarded / approved / returned / rejected
  def done
    my_logs = ActivityLog.where(trackable_type: "Tour", actor_id: current_user.id, action: %w[l1_approved l2_approved extra_forwarded approved returned rejected])
    my_logs = my_logs.where(action: params[:action_type]) if params[:action_type].present?
    tour_ids = my_logs.select(:trackable_id)
    # a tour returned to the employee (by L1, L2 or a later step) is also shown to its L1 and L2 until it is sent again
    chain_returned = Tour.returned.where(approver: current_user).or(Tour.returned.where(l2_approver: current_user)).select(:id)
    chain_returned = Tour.none.select(:id) unless params[:action_type].blank? || params[:action_type] == "returned"
    @tours = Tour.type_tour.where(id: tour_ids).or(Tour.type_tour.where(id: chain_returned)).includes(:user, :approver, :l2_approver)
    @tours = search_tours(@tours)   # name, code, location, place, reference …
    @tours = within_tour_dates(@tours).order(updated_at: :desc).page(params[:page]).per(30)
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
    back_to_list(nxt ? "forwarded to #{nxt}" : "approved")
  end

  def send_back
    @tour.return!(by: current_user, remark: remark!)
    back_to_list("returned to #{@tour.user.name} for correction")
  end

  def reject
    @tour.reject!(by: current_user, remark: remark!)
    back_to_list("rejected")
  end

  private

  def set_pending_tour
    @tour = Tour.find(params[:id])
    raise CanCan::AccessDenied, "This tour is not pending with you" unless @tour.approvable_by?(current_user)
  end

  # Always come back to the pending list, never straight into the next tour: an approver
  # who lands on somebody else's tour cannot tell whose plan the message belonged to, and
  # a second Approve click would act on a tour they have not read.
  # The list carries the confirmation and they pick the next one themselves.
  def back_to_list(what)
    whose = "#{@tour.user.name} (#{@tour.user.emp_code})"
    left  = Tour.pending_for(current_user).count
    tail  = left.zero? ? "No tour is left for your approval." : "#{left} tour#{"s" unless left == 1} still pending with you."
    redirect_to approvals_tours_path, notice: "Tour plan of #{whose} for #{@tour.duration_label} #{what}. #{tail}"
  end

  def remark!
    params[:remark].to_s.strip.presence or raise Workflow::RemarkRequired, "Please write a remark before Approve / Return / Reject."
  end
end
