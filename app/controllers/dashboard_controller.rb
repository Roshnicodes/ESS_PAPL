class DashboardController < ApplicationController
  def index
    tours = current_user.tours
    @last_tour  = tours.type_tour.newest_first.first
    @last_claim = current_user.tour_claims.includes(:tour).newest_first.first
    @pending_tour_approvals = Tour.pending_for(current_user).count
    @pending_claims = TourClaim.in_queue_of(current_user).count
    today = Date.current
    @on_tour_count = Tour.on_tour_between(today, today).count
    @claim_ready = tours.approved.where.missing(:tour_claim).select(&:claimable?).first(4)
  end
end
