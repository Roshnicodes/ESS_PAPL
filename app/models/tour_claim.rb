# TA/DA claim (outstation tour) or Local Mileage claim, raised against an approved Tour.
#
# Workflow (same people as the tour, then PD Finance):
#   draft ──send──▶ submitted (L1) ──L1 approve──▶ l1_approved (L2) ──L2 approve──▶ finance_pending ──PD Finance──▶ approved
#   no L2 set  → L1 approve goes straight to finance_pending
#   any reviewer can return it (remark required) → rejected → employee edits & sends again
#   PD Finance must pick Project + Budget line item + Code before approving.
#   Finance can also send it back to L1 / L2 with a question (finance_query) → they reply → finance_pending again.
class TourClaim < ApplicationRecord
  include Auditable
  include BlockedWords
  include SoftDeletable

  STATUSES = %w[draft submitted l1_approved extra_pending finance_pending finance_query approved returned rejected cancelled].index_by(&:itself).freeze
  IN_PROCESS = %w[submitted l1_approved extra_pending finance_pending finance_query].freeze
  enum :status, STATUSES, validate: true
  enum :claim_type, Tour::TYPES, prefix: :type, validate: true

  SECTIONS = {
    claim_city_travels: :city_travel_total,
    claim_local_travels: :local_travel_total,
    claim_lodgings: :lodging_total,
    claim_daily_allowances: :da_total,
    claim_incidentals: :incidental_total
  }.freeze

  belongs_to :tour
  has_many   :claim_queries, -> { order(:created_at) }, dependent: :delete_all
  # extra approvals after L1 → L2 (Flight → Director, Personal Four Wheeler → COO → Director, Train AC / Tatkal → COO)
  has_many   :approval_steps, -> { order(:position) }, class_name: "ClaimApprovalStep", dependent: :delete_all, inverse_of: :tour_claim
  belongs_to :extra_approver, class_name: "User", optional: true   # extra approver the claim is waiting for now
  belongs_to :user
  belongs_to :bank_account, -> { unscope(where: :deleted_at) }, optional: true   # account the employee wants the money in
  belongs_to :project,               optional: true
  belongs_to :budget_line_item,      optional: true
  belongs_to :budget_line_item_code, optional: true
  belongs_to :l1_approver,    class_name: "User", optional: true
  belongs_to :l2_approver,    class_name: "User", optional: true
  belongs_to :l1_approved_by, class_name: "User", optional: true
  belongs_to :l2_approved_by, class_name: "User", optional: true
  belongs_to :finance_approver, class_name: "User", optional: true   # PD Finance chosen by HR for this employee
  belongs_to :approved_by,    class_name: "User", optional: true
  belongs_to :rejected_by,    class_name: "User", optional: true
  belongs_to :returned_by,    class_name: "User", optional: true
  belongs_to :utr_updated_by, class_name: "User", optional: true   # PD Finance who recorded the payment UTR

  blank_row = ->(keys) { ->(a) { a["id"].blank? && keys.all? { |k| a[k.to_s].blank? } } }
  has_many :claim_city_travels,     -> { order(:travel_date, :position) }, dependent: :destroy, inverse_of: :tour_claim
  has_many :claim_local_travels,    -> { order(:travel_date, :position) }, dependent: :destroy, inverse_of: :tour_claim
  has_many :claim_lodgings,         -> { order(:from_date, :position) },   dependent: :destroy, inverse_of: :tour_claim
  has_many :claim_daily_allowances, -> { order(:departure_at, :position) }, dependent: :destroy, inverse_of: :tour_claim
  has_many :claim_incidentals,      -> { order(:expense_date, :position) }, dependent: :destroy, inverse_of: :tour_claim
  has_many :claim_visit_reports,    -> { order(:visit_date, :position) },  dependent: :destroy, inverse_of: :tour_claim

  accepts_nested_attributes_for :claim_city_travels,     allow_destroy: true, reject_if: blank_row.(%i[travel_date departure_city arrival_city amount])
  accepts_nested_attributes_for :claim_local_travels,    allow_destroy: true, reject_if: blank_row.(%i[travel_date place_from place_to kilometers])
  accepts_nested_attributes_for :claim_lodgings,         allow_destroy: true, reject_if: blank_row.(%i[from_date to_date city_id place_name])
  accepts_nested_attributes_for :claim_daily_allowances, allow_destroy: true, reject_if: blank_row.(%i[departure_city departure_at arrival_at])
  accepts_nested_attributes_for :claim_incidentals,      allow_destroy: true, reject_if: blank_row.(%i[expense_date particular amount])
  accepts_nested_attributes_for :claim_visit_reports,    allow_destroy: true, reject_if: blank_row.(%i[visit_date place_visited tasks_accomplished])

  validates :advance_amount, numericality: { greater_than_or_equal_to: 0 }
  # Payment Advice: the bank reference typed by PD Finance after the money is sent.
  validates :utr_no, length: { in: 4..60 }, format: { with: /\A[A-Z0-9][A-Z0-9\/\-]*\z/,
            message: "may use only letters, digits, / and -" }, allow_nil: true
  validate  :utr_only_on_approved_claim
  # Helmet declaration is asked only when a two-wheeler is used.
  validates :helmet_declaration, acceptance: { accept: true, message: "must be ticked for two-wheeler travel" },
                                 if: -> { submitting? && two_wheeler_used? }
  validate  :tour_is_claimable, on: :create
  validate  :has_some_expense, if: :submitting?
  validate  :bank_account_chosen, if: :submitting?
  validate  :reports_have_tasks, if: :submitting?
  validate  :bank_account_is_own, if: :bank_account_id_changed?
  validate  :lines_inside_tour_dates
  validate  :local_month_still_open, if: -> { type_local? && (submitting? || new_record?) }

  normalizes :utr_no, with: ->(v) { v.to_s.strip.upcase.gsub(/\s+/, "").presence }
  normalizes :payment_remark, with: ->(v) { v.to_s.squish.presence }

  strip_blocked_words_from :general_description
  before_validation :inherit_from_tour, on: :create
  before_validation :default_advance_to_zero
  before_save       :recalculate_totals
  after_create -> { log_activity!(:claim_created, actor: user, to: status) }

  # everything a claim page shows, in a handful of queries
  scope :with_lines, -> {
    includes({ claim_city_travels: :travel_mode }, { claim_local_travels: :travel_mode }, { claim_lodgings: :city },
             { claim_daily_allowances: :city }, :claim_incidentals, :claim_visit_reports,
             :project, :budget_line_item, :budget_line_item_code, :l1_approver, :l2_approver, :finance_approver,
             :approved_by, :returned_by, :rejected_by, :extra_approver, { approval_steps: :approver }, { user: :location },
             { bank_account: { passbook_attachment: :blob } })
  }
  scope :newest_first, -> { order(updated_at: :desc, id: :desc) }
  # Payment Advice working lists
  scope :awaiting_payment, -> { approved.where(utr_no: nil) }
  scope :paid,             -> { approved.where.not(utr_no: nil) }

  # Whose payment this person records: PD Finance / admin settle everything; a named
  # Finance approver settles the employees HR put them on (and anything they approved).
  def self.payable_by(user)
    return all if user.finance?
    where(finance_approver_id: user.id).or(where(approved_by_id: user.id))
  end
  scope :in_queue_of, ->(u) {
    queues = where(status: "submitted", l1_approver_id: u.id).or(where(status: "l1_approved", l2_approver_id: u.id))
    queues = queues.or(where(status: "finance_pending", finance_approver_id: u.id))
    queues = queues.or(where(status: "extra_pending", extra_approver_id: u.id))
    queues = queues.or(where(status: "finance_query", id: ClaimQuery.open.where(asked_to_id: u.id).select(:tour_claim_id)))
    finance_pool?(u) ? queues.or(where(status: "finance_pending", finance_approver_id: nil)) : queues
  }

  # Claims without a named Finance person go to PD Finance (same people who get the notification).
  # Admin sees them as "pending" only if there is no active PD Finance user at all, so nothing gets stuck.
  def self.finance_pool?(u)
    u.pd_finance? || (u.admin? && !User.active.where(role: "pd_finance").exists?)
  end

  attr_accessor :submitting

  # ---- Factory -------------------------------------------------------------

  def self.build_for(tour)
    claim = tour.build_tour_claim(user: tour.user, claim_type: tour.tour_type, general_description: tour.general_description,
                                  bank_account: tour.user.bank_accounts.usable.ordered.first)
    claim.seed_daily_visit_reports
    claim
  end

  # The travel report needs one row per tour day so the employee can record
  # the work completed on every date, not only the dates planned as visits.
  # Existing rows are preserved when an older draft is reopened.
  def seed_daily_visit_reports
    return if type_local? || tour.blank? || tour.from_date.blank? || tour.to_date.blank?

    visits_by_date = tour.tour_visits.to_a.group_by(&:visit_date)
    fallback_place = visits_by_date.values.flatten.first&.place
    reported_dates = claim_visit_reports.filter_map(&:visit_date)

    tour.from_date.upto(tour.to_date).each_with_index do |date, position|
      next if reported_dates.include?(date)

      visit = visits_by_date[date]&.first
      claim_visit_reports.build(
        tour_visit: visit,
        planned_date: date,
        visit_date: date,
        place_visited: visit&.place || fallback_place,
        position: position
      )
    end
  end

  # ---- Permissions helpers ------------------------------------------------

  def employee_editable? = draft? || returned?   # rejected is final
  def submitting? = !!submitting

  # ---- Local mileage month window -----------------------------------------
  # A local claim for month M may be sent only till the cutoff day of M+1 (PD HR
  # sets that day globally or per employee). After it the month is closed for good.
  # Not memoized: it reads Date.current, and a claim object outliving midnight
  # (or a background job) must see today's window, not the one it was built in.
  def local_period = (LocalMileagePeriod.new(user) if user)

  def local_claim_month = tour&.claim_month

  def local_month_closed?
    return false unless type_local? && local_claim_month && local_period
    local_period.closed?(local_claim_month)
  end

  # Last date this local claim may be sent for approval.
  def local_send_by = (local_period.deadline_for(local_claim_month) if type_local? && local_claim_month && local_period)

  def local_month_closed_message = local_period&.closed_message(local_claim_month)

  def current_reviewer?(u)
    (submitted? && l1_approver_id == u.id) ||
      (l1_approved? && l2_approver_id == u.id) ||
      (extra_pending? && extra_approver_id == u.id) ||
      (finance_pending? && (finance_approver_id ? finance_approver_id == u.id : self.class.finance_pool?(u)))
  end

  # :l1, :l2 or :finance – which step the current reviewer is doing (:reply = answering Finance's question)
  def review_step
    { "submitted" => :l1, "l1_approved" => :l2, "extra_pending" => :extra, "finance_pending" => :finance, "finance_query" => :reply }[status]
  end

  # ---- extra approvals (same rules as the tour plan) -------------------------------------------
  # modes that need extra approval: the tour's visits (incl. Tatkal) + modes used in A. Travel / B. Local Travel
  def extra_needs
    needs = tour ? tour.extra_needs.map { |_visit, label, chain| [ label, chain ] } : []
    (claim_city_travels + claim_local_travels).reject(&:marked_for_destruction?).filter_map(&:travel_mode).uniq.each do |m|
      chain = m.approver_chain.map { |a| [ a.user_id, a.position ] }
      needs << [ m.name, chain ] if chain.any?
    end
    # Tatkal train ticket in A. Travel → that train's Tatkal approver (e.g. COO)
    claim_city_travels.reject(&:marked_for_destruction?).select(&:tatkal?).filter_map(&:travel_mode).uniq.each do |m|
      chain = m.tatkal_chain.map { |a| [ a.user_id, a.position ] }
      needs << [ "#{m.name} – Tatkal", chain ] if chain.any?
    end
    needs
  end

  def extra_reason = extra_needs.map(&:first).uniq.join(", ").presence
  def pending_steps = approval_steps.reject(&:done?)
  def current_step  = (pending_steps.first if extra_pending?)
  def extra_label   = current_step&.label || extra_approver&.designation.presence || extra_approver&.name

  # who gets it after the current reviewer: "Sunil Mehta", "Director", or the Finance person
  def next_reviewer_label
    nxt = case status
          when "submitted"     then l2_approver ? l2_approver.name : approval_steps.first&.label
          when "l1_approved"   then approval_steps.first&.label
          when "extra_pending" then pending_steps.second&.label
          end
    nxt || (finance_pending? || finance_query? ? nil : (user.finance_approver || finance_approver)&.name || "PD Finance")
  end

  def assign_extra_steps
    chain = ExtraApprovalChain.build(extra_needs, skip: [ user_id, l1_approver_id, l2_approver_id ])
    self.approval_steps = chain.each_with_index.map { |(uid, reason), i| ClaimApprovalStep.new(approver_id: uid, position: i + 1, reason: reason) }
    self.extra_approver = nil
  end

  # after L1 / L2: to the first extra approver if any, otherwise to Finance
  def move_past_l2
    if (first = approval_steps.first)
      self.status = "extra_pending"
      self.extra_approver_id = first.approver_id
    else
      self.status = "finance_pending"
      assign_current_finance_approver
    end
  end

  def open_query = claim_queries.detect(&:open?)
  def query_pending_with?(u) = finance_query? && open_query&.asked_to_id == u.id

  # people Finance can send it back to: Employee (edit & resend), L1 / L2 (reply only)
  def finance_return_options
    [ [ "employee", "Employee – #{user.name} (edit & send again)" ],
      ([ "l1", "L1 – #{l1_approved_by || l1_approver} (reply)" ] if l1_approver_id),
      ([ "l2", "L2 – #{l2_approved_by || l2_approver} (reply)" ] if l2_approver_id) ].compact
  end

  # Finance → L1 / L2 with a question; claim waits for their reply
  def query!(by:, role:, remark:)
    raise Workflow::RemarkRequired if remark.blank?
    to = { "l1" => (l1_approved_by || l1_approver), "l2" => (l2_approved_by || l2_approver) }[role.to_s]
    raise Workflow::NotAllowed, "Choose whom to send it to" if to.nil?
    transition!(by: by, action: :claim_query_sent, remark: remark) do
      ensure_reviewer!(by, "finance_pending")
      claim_queries.create!(asked_by: by, asked_to: to, asked_to_role: role.to_s, question: remark)
      self.status = "finance_query"
    end
  end

  # L1 / L2 answer (remark required) → back to Finance for approval
  def reply_query!(by:, remark:)
    raise Workflow::RemarkRequired if remark.blank?
    transition!(by: by, action: :claim_query_replied, remark: remark) do
      raise Workflow::NotAllowed, "No question is pending with you" unless query_pending_with?(by)
      open_query.update!(answer: remark, answered_at: Time.current)
      self.status = "finance_pending"
    end
  end

  def stage_label
    case status
    when "draft"           then "Claim form prepared (not sent)"
    when "submitted"       then "Pending with L1 – #{l1_approver}"
    when "l1_approved"     then "Forwarded to L2 – #{l2_approver}"
    when "extra_pending"   then "Forwarded to #{extra_label}"
    when "finance_pending" then "Forwarded to PD Finance#{" – #{finance_approver}" if finance_approver}"
    when "finance_query"   then "Finance query – waiting for reply from #{open_query&.role_label} #{open_query&.asked_to}"
    when "approved"        then approved_by_id == user_id ? "Approved" : "Approved by #{approved_by}"
    when "returned"        then "Returned by #{returned_by} – correct & send again"
    when "rejected"        then "Rejected by #{rejected_by} (final)"
    when "cancelled"       then "Cancelled with tour"
    end
  end

  # ---- Workflow -----------------------------------------------------------

  def submit!(by:)
    transition!(by: by, action: :claim_submitted) do
      raise Workflow::NotAllowed, "Only the employee can send this claim" unless by.id == user_id
      raise Workflow::NotAllowed, "Claim already sent" unless employee_editable?
      self.submitting   = true
      self.submitted_at = Time.current
      self.l1_approver  = user.reporting_manager
      self.l2_approver  = (user.l2_manager unless user.l2_manager_id.nil? || user.l2_manager_id == user.reporting_manager_id)
      raise Workflow::NotAllowed, "L1 (reporting manager) is not set. Contact PD HR." if l1_approver.nil?
      self.finance_approver = user.finance_approver
      assign_extra_steps
      self.returned_at = self.returned_by = self.return_remark = nil
      self.l1_approved_at = self.l1_approved_by = self.l2_approved_at = self.l2_approved_by = nil
      self.status = "submitted"
    end
  end

  # L1 / L2 / extra approval – moves the claim on: L1 → L2 (if set) → extra approvers (COO, Director …) → Finance.
  def forward!(by:, remark: nil)
    step = review_step
    raise Workflow::NotAllowed, "This claim is not pending with you" unless step.in?(%i[l1 l2 extra]) && current_reviewer?(by)
    transition!(by: by, action: :"claim_#{step}_approved", remark: remark) do
      case step
      when :l1
        self.l1_approved_at = Time.current
        self.l1_approved_by = by
        self.l1_remark = remark.presence
        l2_approver ? (self.status = "l1_approved") : move_past_l2
      when :l2
        self.l2_approved_at = Time.current
        self.l2_approved_by = by
        self.l2_remark = remark.presence
        move_past_l2
      when :extra
        current = current_step
        current.update!(acted_at: Time.current, acted_by: by, remark: remark.presence)
        if (nxt = pending_steps.first)
          self.extra_approver_id = nxt.approver_id
        else
          self.extra_approver = nil
          self.status = "finance_pending"
          assign_current_finance_approver
        end
      end
    end
  end

  # Final step goes to the Finance person HR has set on the employee (Employee List → Finance)
  # at the moment the claim reaches finance, so later HR changes are respected.
  def assign_current_finance_approver
    self.finance_approver = user.finance_approver || finance_approver
  end

  # PD Finance approves with a remark only (PAPL: no Project / BLI / BLI Code at approval).
  def approve!(by:, remark: nil)
    transition!(by: by, action: :claim_approved, remark: remark) do
      ensure_reviewer!(by, "finance_pending")
      self.finance_remark = remark.presence
      self.approved_at = Time.current
      self.approved_by = by
      self.status = "approved"
    end
  end

  # Back to the employee for correction; when re-sent it starts again from L1.
  def return!(by:, remark:)
    raise Workflow::RemarkRequired if remark.blank?
    transition!(by: by, action: :claim_returned, remark: remark) do
      raise Workflow::NotAllowed, "This claim is not pending with you" unless current_reviewer?(by)
      self.returned_at   = Time.current
      self.returned_by   = by
      self.return_remark = remark
      self.status = "returned"
    end
  end

  # Final rejection.
  def reject!(by:, remark:)
    raise Workflow::RemarkRequired if remark.blank?
    transition!(by: by, action: :claim_rejected, remark: remark) do
      raise Workflow::NotAllowed, "This claim is not pending with you" unless current_reviewer?(by)
      self.rejected_at   = Time.current
      self.rejected_by   = by
      self.reject_remark = remark
      self.status = "rejected"
    end
  end

  # Called from Tour#cancel! inside the tour's transaction.
  def cancel_with_tour!(by:, remark:)
    from = status
    update!(status: "cancelled", cancelled_at: Time.current)
    log_activity!(:claim_cancelled, actor: by, from: from, to: status, remark: remark)
  end

  # ---- Payment Advice ------------------------------------------------------

  def paid? = utr_no.present?

  # Records (or corrects) the bank reference against an approved claim.
  # Returns false with errors when the claim is not payable or the UTR is malformed.
  def record_payment!(utr:, by:, paid_on: nil, remark: nil)
    was = utr_no
    assign_attributes(utr_no: utr, paid_on: paid_on.presence || paid_on_default(was),
                      payment_remark: remark, utr_updated_by: by, utr_updated_at: Time.current)
    return false unless save
    log_activity!(was.present? ? :payment_utr_corrected : :payment_recorded, actor: by,
                  details: { utr: utr_no, was: was, paid_on: paid_on&.to_s, amount: balance_amount.to_s }.compact)
    Notifier.payment(self, actor: by)
    true
  end

  def paid_on_default(previous) = previous.present? ? paid_on : Date.current

  def two_wheeler_used?
    claim_local_travels.reject(&:marked_for_destruction?).any? { |l| l.travel_mode&.name.to_s =~ /two/i } ||
      claim_city_travels.reject(&:marked_for_destruction?).any? { |l| l.travel_mode&.name.to_s =~ /two/i }
  end

  def to_s = "Claim · #{tour.duration_label}"

  private

  def transition!(by:, action:, remark: nil)
    with_lock do
      from = status
      yield
      save!
      log_activity!(action, actor: by, from: from, to: status, remark: remark,
                    details: { grand_total: grand_total.to_s, balance: balance_amount.to_s })
      Notifier.claim(self, action, actor: by, remark: remark)
    end
    self
  end

  def ensure_reviewer!(by, expected)
    raise Workflow::NotAllowed, "Claim is not at this stage" unless status == expected
    raise Workflow::NotAllowed, "This claim is not pending with you" unless current_reviewer?(by)
  end

  def inherit_from_tour
    return unless tour
    self.user ||= tour.user
    self.claim_type = tour.tour_type
  end

  def recalculate_totals
    SECTIONS.each do |assoc, column|
      self[column] = public_send(assoc).reject(&:marked_for_destruction?).sum { |l| l.total_amount.to_d }
    end
    self.grand_total    = SECTIONS.values.sum { |c| self[c].to_d }
    self.balance_amount = grand_total - advance_amount.to_d
  end

  def tour_is_claimable
    return errors.add(:tour, "is required") unless tour
    errors.add(:base, "Tour must be approved before preparing the claim") unless tour.approved?
    if tour.approved? && !tour.claimable?
      errors.add(:base, "Claim form opens on #{tour.claim_open_on.strftime('%d/%m/%Y')} (after tour To-Date)")
    end
  end

  # Blank "Less Advance Taken" means no advance was taken.
  def default_advance_to_zero
    self.advance_amount = 0 if advance_amount.blank?
  end

  def local_month_still_open
    errors.add(:base, local_month_closed_message) if local_month_closed?
  end

  def has_some_expense
    lines = SECTIONS.keys.flat_map { |a| public_send(a).reject(&:marked_for_destruction?) }
    errors.add(:base, "Add at least one expense row before sending") if lines.empty?
  end

  def lines_inside_tour_dates
    return unless tour
    range = tour.from_date..tour.to_date
    dated = claim_city_travels.map(&:travel_date) + claim_local_travels.map(&:travel_date) + claim_incidentals.map(&:expense_date)
    outside = dated.compact.reject { |d| range.cover?(d) }
    errors.add(:base, "Expense dates must be within #{tour.duration_label}") if outside.any?
  end

  # Brief detail of travel: every column is mandatory for every row before sending (saving a draft is fine)
  REPORT_FIELDS = { tasks_accomplished: "Tasks Accomplished", action_points: "Action Points", time_frame: "Time frame", remark: "Remark" }.freeze

  def reports_have_tasks
    claim_visit_reports.reject(&:marked_for_destruction?).each do |r|
      blank = REPORT_FIELDS.select { |attr, _| r.public_send(attr).blank? }.values
      next if blank.empty?
      errors.add(:base, "Brief detail of travel (#{r.visit_date&.strftime('%d/%m/%Y')}): fill #{blank.to_sentence}")
    end
  end

  def bank_account_chosen
    errors.add(:bank_account, "– choose the bank account for payment (add one from Bank Details)") if bank_account.nil?
  end

  def bank_account_is_own
    return if bank_account_id.nil?
    errors.add(:bank_account, "is not valid") unless BankAccount.usable.exists?(id: bank_account_id, user_id: user_id)
  end

  def utr_only_on_approved_claim
    errors.add(:utr_no, "can be recorded only on an approved claim") if utr_no.present? && !approved?
  end
end
