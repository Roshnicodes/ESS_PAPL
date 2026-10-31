# Claim approval: L1 -> L2 (if set) -> PD Finance.
class Approvals::ClaimsController < ApplicationController
  before_action :set_claim, except: :index
  before_action -> { redirect_to authenticated_root_path, alert: "Approvals are only for approvers." unless current_user.claim_approver? }, only: :index

  def index
    @type  = params[:type].to_s == "local" ? "local" : "tour"
    @scope = params[:scope].to_s == "approved" ? "approved" : "pending"
    base = TourClaim.where(claim_type: @type).includes(:user, :tour, :approved_by, :project)
    @claims =
      if @scope == "approved"
        (current_user.finance? || current_user.hr? ? base : base.where(user: current_user).or(base.where(l1_approver: current_user)).or(base.where(l2_approver: current_user)).or(base.where(finance_approver: current_user)).or(base.where(id: ClaimApprovalStep.where(approver_id: current_user.id).select(:tour_claim_id))))
          .approved.order(approved_at: :desc)
      else
        base.in_queue_of(current_user).order(:submitted_at)
      end
    respond_to do |format|
      format.html { @claims = @claims.page(params[:page]).per(25) }
      format.xlsx do
        send_data ClaimExport.new(@claims.includes(:budget_line_item, :budget_line_item_code, :l1_approved_by, :l2_approved_by, :bank_account), viewer: current_user).to_xlsx,
                  filename: "#{@type == 'local' ? 'local_mileage' : 'tada'}_claims_#{@scope}_#{Date.current}.xlsx",
                  type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      end
      format.csv do
        send_data ClaimExport.new(@claims.includes(:budget_line_item, :budget_line_item_code, :l1_approved_by, :l2_approved_by, :bank_account), viewer: current_user).to_csv,
                  filename: "#{@type == 'local' ? 'local_mileage' : 'tada'}_claims_#{@scope}_#{Date.current}.csv", type: "text/csv"
      end
    end
  end

  def show
    authorize! :read, @claim
    @logs = @claim.activity_logs.includes(:actor)
    @tour_logs = @claim.tour.activity_logs.includes(:actor)
    @reviewing = @claim.current_reviewer?(current_user)
    @replying  = @claim.query_pending_with?(current_user)
  end

  # Reviewer may apply deductions (amount, remark) before acting.
  def update
    authorize! :review, @claim
    TourClaim.transaction { save_deductions! }
    redirect_to approvals_claim_path(@claim), notice: "Deductions saved."
  rescue ActiveRecord::RecordInvalid
    render_review_again
  end

  # L1 / L2 approval
  def forward
    authorize! :review, @claim
    remark = remark!
    TourClaim.transaction { save_deductions!; @claim.forward!(by: current_user, remark: remark) }
    nxt = if @claim.l1_approved? then "L2 – #{@claim.l2_approver}"
          elsif @claim.extra_pending? then @claim.extra_label
          else "Finance – #{@claim.finance_approver || 'PD Finance'}" end
    redirect_to approvals_claims_path(type: @claim.claim_type), notice: "Claim forwarded to #{nxt}."
  rescue ActiveRecord::RecordInvalid
    render_review_again
  end

  def approve
    authorize! :review, @claim
    remark = remark!
    TourClaim.transaction { save_deductions!; @claim.approve!(by: current_user, remark: remark,
      project_id: params[:project_id], budget_line_item_id: params[:budget_line_item_id],
      budget_line_item_code_id: params[:budget_line_item_code_id]) }
    redirect_to approvals_claims_path(type: @claim.claim_type), notice: "Claim approved."
  rescue ActiveRecord::RecordInvalid
    render_review_again
  end

  # Return – L1 / L2: to the employee. Finance chooses: employee (edit & resend) or L1 / L2 (they reply, then back to Finance).
  def send_back
    authorize! :review, @claim
    remark = remark!
    to = @claim.review_step == :finance ? params[:return_to].to_s.presence || "employee" : "employee"
    TourClaim.transaction do
      save_deductions!
      to == "employee" ? @claim.return!(by: current_user, remark: remark) : @claim.query!(by: current_user, role: to, remark: remark)
    end
    notice = to == "employee" ? "Claim returned to #{@claim.user} for correction." :
                                "Claim sent to #{to.upcase} – #{@claim.open_query.asked_to} for reply. It comes back to you after the reply."
    redirect_to approvals_claims_path(type: @claim.claim_type), notice: notice
  rescue ActiveRecord::RecordInvalid
    render_review_again
  end

  # L1 / L2 answer Finance's question (remark required) → claim goes back to Finance
  def reply
    raise CanCan::AccessDenied, "No question is pending with you" unless @claim.query_pending_with?(current_user)
    @claim.reply_query!(by: current_user, remark: remark!)
    redirect_to approvals_claims_path(type: @claim.claim_type), notice: "Reply sent – claim is back with Finance for approval."
  end

  def reject
    authorize! :review, @claim
    remark = remark!
    TourClaim.transaction { save_deductions!; @claim.reject!(by: current_user, remark: remark) }
    redirect_to approvals_claims_path(type: @claim.claim_type), notice: "Claim rejected."
  rescue ActiveRecord::RecordInvalid
    render_review_again
  end

  private

  # Deductions typed on the review page are saved first (and logged), then the action runs.
  def save_deductions!
    return unless params[:tour_claim].present?
    @claim.assign_attributes(deduction_params)
    changes = deduction_changes
    @claim.save!
    @claim.log_activity!(:deduction_updated, details: { lines: changes }) if changes.any?
  end

  def render_review_again
    @claim.status = @claim.status_in_database   # keep typed deductions, undo the failed step
    @logs = @claim.activity_logs.includes(:actor)
    @tour_logs = @claim.tour.activity_logs.includes(:actor)
    @reviewing = true
    render :show, status: :unprocessable_entity
  end

  def remark!
    params[:remark].to_s.strip.presence or raise Workflow::RemarkRequired, "Please write a remark before Approve / Return / Reject."
  end

  def set_claim
    @claim = TourClaim.with_lines.includes(:tour).find(params[:id])
  end

  DEDUCTION = %i[id deduction_amount deduction_remark].freeze

  def deduction_params
    params.require(:tour_claim).permit(
      TourClaim::SECTIONS.keys.index_with { DEDUCTION }.transform_keys { |k| :"#{k}_attributes" }
    )
  end

  def deduction_changes
    TourClaim::SECTIONS.keys.flat_map do |assoc|
      @claim.public_send(assoc).select(&:changed?).map do |l|
        { section: assoc, id: l.id, item: deduction_line_label(assoc, l),
          deduction: l.changes["deduction_amount"]&.map(&:to_s), remark: l.deduction_remark }
      end
    end
  end

  # Kept in the immutable activity entry because a reviewer needs to see what
  # was deducted even if the original claim line is later corrected.
  def deduction_line_label(section, line)
    case section
    when :claim_city_travels
      [ line.travel_date&.strftime("%d/%m/%Y"), line.departure_city, "→", line.arrival_city, line.travel_mode&.name ].compact.join(" · ")
    when :claim_local_travels
      [ line.travel_date&.strftime("%d/%m/%Y"), line.place_from, "→", line.place_to, line.travel_mode&.name ].compact.join(" · ")
    when :claim_lodgings
      [ line.lodging_date&.strftime("%d/%m/%Y"), line.place_label ].compact.join(" · ")
    when :claim_daily_allowances
      [ line.departure_city, "→", line.arrival_label ].compact.join(" ")
    when :claim_incidentals
      [ line.expense_date&.strftime("%d/%m/%Y"), line.particular, line.bill_no.presence ].compact.join(" · ")
    else
      section.to_s.humanize
    end
  end
end
