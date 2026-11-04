class DashboardController < ApplicationController
  def index
    tours = current_user.tours
    @last_tour  = tours.type_tour.newest_first.first
    @last_claim = current_user.tour_claims.includes(:tour).newest_first.first
    @pending_tour_approvals = Tour.pending_for(current_user).count
    @pending_claims = TourClaim.in_queue_of(current_user).count
    today = Date.current
    @on_tour_count = Tour.on_tour_on(today).count
    @claim_ready = tours.approved.where.missing(:tour_claim).select(&:claimable?).first(4)
  end

  # Who is on tour on a day (today unless ?date=): approved plans and plans still waiting for approval,
  # waiting ones first. Clicking a person opens the whole plan.
  def on_tour
    @date = (Date.parse(params[:date].to_s) rescue nil) || Date.current
    @tours = Tour.on_tour_on(@date)
                 .includes(:approver, :l2_approver, :decided_by, { approval_steps: :approver }, { tour_visits: :travel_mode }, user: :location)
                 .joins(:user).order(Arel.sql("CASE WHEN tours.status = 'approved' THEN 1 ELSE 0 END"), "users.name")
  end
end
