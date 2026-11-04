# Admin: every tour of every employee – view, edit, delete.
class Masters::AllToursController < ApplicationController
  before_action { raise CanCan::AccessDenied, "Only admin" unless current_user.admin? }

  def index
    # what needs action comes first: plan or claim waiting with someone, then returned, then the finished ones;
    # merely saved (draft plan / "prepared" claim not sent) at the end – newest first inside each group
    claim_status = "(SELECT tc.status FROM tour_claims tc WHERE tc.tour_id = tours.id LIMIT 1)"
    @tours = Tour.includes(:user, :approver, :l2_approver, :tour_claim).order(Arel.sql(<<~SQL.squish), created_at: :desc)
      CASE
        WHEN tours.status IN ('submitted', 'l1_approved', 'l2_approved')
          OR #{claim_status} IN (#{TourClaim::IN_PROCESS.map { "'#{_1}'" }.join(', ')}) THEN 0
        WHEN tours.status = 'returned' OR #{claim_status} = 'returned' THEN 1
        WHEN tours.status = 'draft' OR #{claim_status} = 'draft' THEN 3
        ELSE 2
      END
    SQL
    if params[:q].present?
      q = "%#{Tour.sanitize_sql_like(params[:q].strip)}%"
      @tours = @tours.joins(:user).where("users.name ILIKE :q OR users.emp_code ILIKE :q", q: q)
    end
    @tours = @tours.where(status: params[:status]) if params[:status].present?
    @tours = @tours.where(tour_type: params[:type]) if params[:type].present?
    @tours = @tours.page(params[:page]).per(30)
  end
end
