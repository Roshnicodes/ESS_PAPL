# Admin: every tour of every employee – view, edit, delete.
# Filters: employee, type, stage (pending / plan approved / claim approved / prepared …), tour status,
# a date range on the tour dates, and the sort order HR wants (latest first by default).
class Masters::AllToursController < ApplicationController
  before_action { raise CanCan::AccessDenied, "Only admin" unless current_user.admin? }

  CLAIM_STATUS = "(SELECT c.status FROM tour_claims c WHERE c.tour_id = tours.id LIMIT 1)".freeze
  TOUR_PENDING  = "tours.status IN ('submitted', 'l1_approved', 'l2_approved')".freeze
  CLAIM_PENDING = "#{CLAIM_STATUS} IN ('submitted', 'l1_approved', 'extra_pending', 'finance_pending', 'finance_query')".freeze
  PREPARED = "(tours.status = 'draft' OR (tours.tour_type = 'local' AND COALESCE(#{CLAIM_STATUS}, 'draft') = 'draft'))".freeze

  # Pending (tour or its claim waiting with someone) first, then everything else, only-saved last.
  PENDING_FIRST = <<~SQL.squish.freeze
    CASE WHEN #{TOUR_PENDING} OR #{CLAIM_PENDING} THEN 0 WHEN #{PREPARED} THEN 2 ELSE 1 END
  SQL

  STAGES = {
    "pending"        => [ "Pending (tour or claim)", "(#{TOUR_PENDING} OR #{CLAIM_PENDING})" ],
    "tour_pending"   => [ "Tour plan pending",       TOUR_PENDING ],
    "claim_pending"  => [ "Claim pending",           CLAIM_PENDING ],
    "plan_approved"  => [ "Plan approved – no claim yet", "tours.tour_type = 'tour' AND tours.status = 'approved' AND #{CLAIM_STATUS} IS NULL" ],
    "claim_approved" => [ "Claim approved",          "#{CLAIM_STATUS} = 'approved'" ],
    "prepared"       => [ "Prepared / saved (not sent)", "(#{PREPARED} OR #{CLAIM_STATUS} = 'draft')" ],
    "returned"       => [ "Returned",                "(tours.status = 'returned' OR #{CLAIM_STATUS} = 'returned')" ],
    "rejected"       => [ "Rejected",                "(tours.status = 'rejected' OR #{CLAIM_STATUS} = 'rejected')" ],
    "cancelled"      => [ "Cancelled",               "tours.status = 'cancelled'" ]
  }.freeze

  SORTS = {
    "newest"        => [ "Latest created first", "tours.created_at DESC, tours.id DESC" ],
    "oldest"        => [ "Oldest created first", "tours.created_at ASC, tours.id ASC" ],
    "tour_date_desc" => [ "Tour date – latest first", "tours.from_date DESC, tours.id DESC" ],
    "tour_date_asc"  => [ "Tour date – oldest first", "tours.from_date ASC, tours.id ASC" ],
    "pending_first" => [ "Pending first", "#{PENDING_FIRST}, tours.created_at DESC" ],
    "employee"      => [ "Employee name A–Z", "users.name ASC, tours.created_at DESC" ]
  }.freeze

  def index
    @sort = SORTS.key?(params[:sort]) ? params[:sort] : "pending_first"   # PAPL: what needs action first
    @tours = Tour.includes(:user, :approver, :l2_approver, :tour_claim).joins(:user)
    if params[:q].present?
      q = "%#{Tour.sanitize_sql_like(params[:q].strip)}%"
      @tours = @tours.where("users.name ILIKE :q OR users.emp_code ILIKE :q", q: q)
    end
    @tours = @tours.where(status: params[:status]) if params[:status].present?
    @tours = @tours.where(tour_type: params[:type]) if params[:type].present?
    @tours = @tours.where(STAGES[params[:stage]].last) if STAGES.key?(params[:stage])
    @from = parse_date(params[:from]); @to = parse_date(params[:to])
    @tours = @tours.where("tours.to_date >= ?", @from) if @from       # tour dates overlapping the range
    @tours = @tours.where("tours.from_date <= ?", @to) if @to
    @total = @tours.count
    @tours = @tours.order(Arel.sql(SORTS[@sort].last)).page(params[:page]).per(30)
  end

  private

  def parse_date(value)
    Date.parse(value.to_s) if value.present?
  rescue Date::Error
    nil
  end
end
