class DashboardController < ApplicationController
  def index
    u = current_user
    tours = u.tours
    today = Date.current
    @last_tour  = tours.type_tour.includes(:tour_visits).newest_first.first
    @last_claim = u.tour_claims.includes(:tour).newest_first.first
    @pending_tour_approvals = Tour.pending_for(u).count
    @pending_claims = TourClaim.in_queue_of(u).count
    @on_tour_count = Tour.planned_on(today).count
    @on_tour_list  = Tour.planned_on(today).includes(:tour_visits, user: :location).order(:from_date).limit(5).to_a
    @on_tour_faces = @on_tour_list.map(&:user)
    @claim_ready = tours.approved.where.missing(:tour_claim).select(&:claimable?).first(4)

    # things of mine that came back / wait to be sent
    @returned_tours  = tours.where(status: "returned").order(updated_at: :desc).limit(3)
    @returned_claims = u.tour_claims.where(status: "returned").includes(:tour).order(updated_at: :desc).limit(3)
    period = LocalMileagePeriod.new(u)
    local = tours.type_local.live.find_by(claim_month: period.month)
    @local_unsent = local if local&.tour_claim&.draft?
    @local_deadline = period.deadline_for(period.month)

    # my money this financial year
    fy = FinancialYear.current
    mine = u.tour_claims.joins(:tour).where("COALESCE(tours.claim_month, tours.from_date) BETWEEN ? AND ?", fy.from, fy.to)
    @fy_label = fy.label
    @money = {
      in_process: mine.where(status: %w[submitted l1_approved extra_pending finance_pending finance_query]).sum(:grand_total),
      approved:   mine.where(status: "approved", utr_no: nil).sum(:balance_amount),
      paid:       mine.where(status: "approved").where.not(utr_no: nil).sum(:balance_amount)
    }
    @last_paid = u.tour_claims.paid.includes(:tour).order(utr_updated_at: :desc).first

    # IOM / Circular
    @circulars = (u.admin? ? Circular.live : Circular.live.visible_to(u)).with_attached_attachments.newest_first.limit(5).to_a
    @unread_circular_ids = u.notifications.unread.where(notifiable_type: "Circular").pluck(:notifiable_id).to_set

    # PD HR / admin: the organisation at a glance
    if u.hr?
      @org = {
        employees:      User.active.count,
        tours_pending:  Tour.type_tour.where(status: %w[submitted l1_approved l2_approved]).count,
        claims_pending: TourClaim.where(status: %w[submitted l1_approved extra_pending finance_query]).count,
        with_finance:   TourClaim.where(status: "finance_pending").count,
        utr_pending:    TourClaim.awaiting_payment.count
      }
    end

    # PD Finance work
    if u.finance_person?
      @utr_pending   = TourClaim.awaiting_payment.payable_by(u).count
    end
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
