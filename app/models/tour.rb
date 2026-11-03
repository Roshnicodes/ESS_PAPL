class Tour < ApplicationRecord
  include Auditable
  include BlockedWords
  include SoftDeletable

  TYPES    = { tour: "tour", local: "local" }.freeze
  STATUSES = { draft: "draft", submitted: "submitted", l1_approved: "l1_approved", l2_approved: "l2_approved", approved: "approved",
               returned: "returned", rejected: "rejected", cancelled: "cancelled" }.freeze
  LIVE     = %w[submitted l1_approved l2_approved approved].freeze   # blocks overlapping dates / second local claim
  EDITABLE = %w[draft returned].freeze   # rejected is final
  ACTIVITY_MAX = 500

  enum :tour_type, TYPES, prefix: :type, validate: true
  enum :status, STATUSES, validate: true

  belongs_to :user
  # Retained for legacy records only. New tours choose no payment account; the
  # employee selects it directly on the claim form.
  belongs_to :bank_account, -> { unscope(where: :deleted_at) }, optional: true
  belongs_to :approver,       class_name: "User", optional: true   # L1 (reporting manager)
  belongs_to :l2_approver,    class_name: "User", optional: true   # L2 (functional manager)
  belongs_to :l3_approver,    class_name: "User", optional: true   # extra approver the tour is waiting for now (L3, L4 …)
  has_many   :approval_steps, -> { order(:position) }, class_name: "TourApprovalStep", dependent: :delete_all, inverse_of: :tour
  belongs_to :l1_approved_by, class_name: "User", optional: true
  belongs_to :l2_approved_by, class_name: "User", optional: true
  belongs_to :decided_by,   class_name: "User", optional: true
  belongs_to :cancelled_by, class_name: "User", optional: true
  belongs_to :returned_by,  class_name: "User", optional: true
  has_many   :tour_visits, -> { order(:visit_date, :position) }, dependent: :destroy, inverse_of: :tour
  has_one    :tour_claim, dependent: :restrict_with_error

  accepts_nested_attributes_for :tour_visits, allow_destroy: true,
    reject_if: ->(a) { a["visit_date"].blank? && a["place"].blank? && a["planned_activity"].blank? }

  scope :live,          -> { where(status: LIVE) }
  scope :newest_first,  -> { order(from_date: :desc, id: :desc) }
  scope :pending_for,   ->(user) { submitted.where(approver: user).or(l1_approved.where(l2_approver: user)).or(l2_approved.where(l3_approver: user)) }
  # approved tour plans whose To-Date is over and no claim made yet → red "claim due" badge
  scope :claim_due,     ->(today = Date.current) { type_tour.approved.where(to_date: ...today).where.missing(:tour_claim) }
  scope :on_tour_between, ->(from, to) { approved.type_tour.where("from_date <= ? AND to_date >= ?", to, from) }

  attr_accessor :send_now   # "Save & Send for Approval" vs plain "Save"

  validates :from_date, :to_date, presence: true
  validates :submitted_at, presence: true, unless: -> { draft? || cancelled? }
  validates :general_description, length: { maximum: 2000 }
  validate  :date_order
  validate  :within_plan_window, if: -> { type_tour? && (new_record? || will_save_change_to_from_date? || will_save_change_to_to_date?) }
  validate  :visits_inside_range
  validate  :tour_needs_visits, if: -> { type_tour? && !draft? }
  validate  :no_overlap, if: -> { type_tour? && status.in?(LIVE) }
  validate  :one_local_per_month, if: -> { type_local? && status.in?(LIVE) }
  validate  :approver_present, if: -> { submitted? && type_tour? }

  strip_blocked_words_from :general_description
  before_validation :prepare_new, on: :create
  before_create     :assign_reference_no
  after_create :log_created

  # ---- Workflow -----------------------------------------------------------

  def editable? = status.in?(EDITABLE)

  # Employee may also edit a tour that is pending or already approved – as long as no claim exists.
  # Saving such a tour sends it for approval again from L1 (see #edit_and_resend!).
  def maker_editable? = type_tour? && (editable? || (status.in?(LIVE) && tour_claim.nil?))
  def needs_reapproval_on_edit? = type_tour? && status.in?(LIVE)

  # Edit of a pending / approved tour: earlier approvals are cleared and it goes to L1 again.
  def edit_and_resend!(attrs, by:)
    raise Workflow::NotAllowed, "Only the employee can edit this tour" unless by.id == user_id
    raise Workflow::NotAllowed, "This tour cannot be edited now" unless maker_editable? && needs_reapproval_on_edit?
    with_lock do
      from = status
      before_visits = tour_visits.map { |v| [ v.visit_date.to_s, v.place, v.travel_mode&.name, v.planned_activity ] }
      assign_attributes(attrs)
      changes = self.changes.slice("from_date", "to_date", "general_description").transform_values { |a| a.map(&:to_s) }
      visits_changed = tour_visits.any? { |v| v.new_record? || v.changed? || v.marked_for_destruction? }
      return self if changes.empty? && !visits_changed   # nothing changed → stays as it is

      assign_approvers
      self.status = "submitted"
      self.submitted_at = Time.current
      self.l1_approved_at = self.l1_approved_by = self.l1_remark = nil
      self.l2_approved_at = self.l2_approved_by = self.l2_remark = nil
      self.approved_at = self.decided_by = self.decision_remark = nil
      save!
      after_visits = tour_visits.reload.map { |v| [ v.visit_date.to_s, v.place, v.travel_mode&.name, v.planned_activity ] }
      changes["visits"] = [ before_visits, after_visits ] if before_visits != after_visits
      log_activity!(:edited_resubmitted, actor: by, from: from, to: status, details: changes.merge(approver_details))
      Notifier.tour(self, :submitted, actor: by)
    end
    self
  end

  # Current approver: L1 while "submitted", L2 while "l1_approved", the pending extra step (L3, L4 …) while "l2_approved".
  def current_approver
    if submitted? then approver
    elsif l1_approved? then l2_approver
    elsif l2_approved? then l3_approver
    end
  end

  # extra approvals after L1 → L2 (e.g. Personal Four Wheeler → COO → Director)
  def pending_steps = approval_steps.reject(&:done?)
  def current_step  = (pending_steps.first if l2_approved?)

  # Who comes after the current approver (nil = current approval is final)
  def next_step
    if submitted? then (approval_steps.first unless l2_approver)
    elsif l1_approved? then approval_steps.first
    elsif l2_approved? then pending_steps.second
    end
  end

  def next_approver
    return l2_approver if submitted? && l2_approver
    next_step&.approver
  end

  # extra approvers are shown by designation (COO, Director), not by name
  def l3_label = current_step&.label || (l3_approver && (l3_approver.designation.presence || l3_approver.name))
  def next_approver_label = next_step ? next_step.label : next_approver&.name

  # Travel modes used in the visits that need extra approval (e.g. Flight, Personal Four Wheeler)
  def l3_modes
    tour_visits.reject(&:marked_for_destruction?).filter_map(&:travel_mode).select(&:needs_extra_approval?).uniq
  end

  def used_modes = tour_visits.reject(&:marked_for_destruction?).filter_map(&:travel_mode).uniq

  # visits that need extra approval and why: [[visit, "Train(3A)" / "Train(SL) – Tatkal", chain], …]
  def extra_needs
    tour_visits.reject(&:marked_for_destruction?).filter_map do |v|
      m = v.travel_mode or next
      # Tatkal is the immediate exception route, so it is placed before the
      # mode's normal route (e.g. 1A Tatkal: COO, then Director).
      chain = v.tatkal? ? m.tatkal_chain.map { |a| [ a.user_id, a.position ] } : []
      chain += m.approver_chain.map { |a| [ a.user_id, a.position ] }
      label = m.name
      if v.tatkal? && m.tatkal_chain.any?
        label = "#{m.name} – Tatkal"
      end
      [ v, label, chain ] if chain.any?
    end
  end

  def extra_reason = extra_needs.map(&:second).uniq.join(", ").presence

  def approvable_by?(actor) = current_approver.present? && current_approver.id == actor.id

  def stage_label
    case status
    when "draft"       then "Saved (not sent)"
    when "submitted"   then "Pending with L1 – #{approver}"
    when "l1_approved" then "Forwarded to L2 – #{l2_approver}"
    when "l2_approved" then "Forwarded to #{l3_label}"
    when "approved"
      if type_local?
        tour_claim.nil? || tour_claim.draft? ? "Prepared (claim not sent)" : "Self-sanctioned"
      else
        "Approved"
      end
    when "returned"    then "Returned by #{returned_by} – correct & send again"
    when "rejected"    then "Rejected by #{decided_by} (final)"
    when "cancelled"   then "Cancelled"
    end
  end

  # Draft / returned -> submitted (goes to L1 again)
  def submit!(by:)
    raise Workflow::NotAllowed, "Only the employee can send this tour" unless by.id == user_id
    raise Workflow::NotAllowed, "Tour is already sent" unless editable?
    from = status
    with_lock do
      assign_approvers
      self.status = "submitted"
      self.submitted_at = Time.current
      self.returned_at = self.returned_by = self.return_remark = nil
      self.l1_approved_at = self.l1_approved_by = self.l1_remark = nil
      self.l2_approved_at = self.l2_approved_by = self.l2_remark = nil
      save!
      log_activity!(:submitted, actor: by, from: from, to: status, details: approver_details)
      Notifier.tour(self, :submitted, actor: by)
    end
    self
  end

  # L1 → L2 (if set) → extra steps in order (if a mode like Flight / Personal Four Wheeler needs them) → approved
  def approve!(by:, remark: nil)
    raise Workflow::NotAllowed, "This tour is not pending with you" unless approvable_by?(by)
    if l2_approved? && (step = current_step) && (nxt = pending_steps.second)
      # one extra approver done, next one gets it (status stays "l2_approved")
      with_lock do
        step.update!(acted_at: Time.current, acted_by: by, remark: remark.presence)
        self.l3_approver = nxt.approver
        save!
        log_activity!(:extra_forwarded, actor: by, from: status, to: status, remark: remark, details: { level: step.level, next: nxt.approver.emp_code })
        Notifier.tour(self, :extra_forwarded, actor: by, remark: remark)
      end
      return self
    end
    if submitted? && l2_approver.present?
      transition!(:l1_approved, by: by, remark: remark) do
        self.l1_approved_at = Time.current
        self.l1_approved_by = by
        self.l1_remark = remark.presence
      end
    elsif (submitted? || l1_approved?) && approval_steps.any?
      transition!(:l2_approved, by: by, remark: remark) do
        if submitted?   # no L2: L1 forwards straight to L3
          self.l1_approved_at = Time.current
          self.l1_approved_by = by
          self.l1_remark = remark.presence
        end
        self.l2_approved_at = Time.current
        self.l2_approved_by = by
        self.l2_remark = remark.presence
        self.l3_approver = approval_steps.first.approver
      end
    else
      transition!(:approved, by: by, remark: remark) do
        current_step&.update!(acted_at: Time.current, acted_by: by, remark: remark.presence)   # last extra step
        if submitted?   # no L2 / L3: L1 approval is final
          self.l1_approved_at = Time.current
          self.l1_approved_by = by
          self.l1_remark = remark.presence
        end
        self.approved_at = Time.current
        self.decided_by = by
        self.decision_remark = remark.presence
      end
    end
  end

  # Back to the employee: they correct it and send again (starts from L1).
  def return!(by:, remark:)
    raise Workflow::RemarkRequired if remark.blank?
    raise Workflow::NotAllowed, "This tour is not pending with you" unless approvable_by?(by)
    transition!(:returned, by: by, remark: remark) do
      self.returned_at = Time.current
      self.returned_by = by
      self.return_remark = remark
    end
  end

  # Final – the tour cannot be sent again.
  def reject!(by:, remark:)
    raise Workflow::RemarkRequired if remark.blank?
    raise Workflow::NotAllowed, "This tour is not pending with you" unless approvable_by?(by)
    transition!(:rejected, by: by, remark: remark) do
      self.rejected_at = Time.current
      self.decided_by = by
      self.decision_remark = remark
    end
  end

  # Employee may cancel any time before the claim is sent (draft, pending, approved), remark mandatory.
  def cancellable?
    (editable? || status.in?(LIVE)) && (tour_claim.nil? || tour_claim.employee_editable?)
  end

  def cancel!(by:, remark:)
    raise Workflow::RemarkRequired if remark.blank?
    transition!(:cancelled, by: by, remark: remark) do
      raise Workflow::NotAllowed, "Only the employee can cancel this tour" unless by.id == user_id || by.admin?
      raise Workflow::NotAllowed, "Tour can no longer be cancelled" unless cancellable?
      self.status_before_cancel = status
      self.cancelled_at = Time.current
      self.cancelled_by = by
      self.cancel_remark = remark
      tour_claim&.cancel_with_tour!(by: by, remark: remark)
    end
  end

  # ---- Admin -------------------------------------------------------------

  # Admin may correct any tour (any status); every change is logged with old → new values.
  def admin_update!(attrs, by:, remark: nil)
    raise Workflow::NotAllowed, "Only admin can do this" unless by.admin?
    with_lock do
      before_visits = tour_visits.map { |v| [ v.visit_date.to_s, v.place, v.travel_mode&.name, v.planned_activity ] }
      assign_attributes(attrs)
      changes = self.changes.slice("from_date", "to_date", "general_description").transform_values { |a| a.map(&:to_s) }
      save!
      after_visits = tour_visits.reload.map { |v| [ v.visit_date.to_s, v.place, v.travel_mode&.name, v.planned_activity ] }
      changes["visits"] = [ before_visits, after_visits ] if before_visits != after_visits
      log_activity!(:admin_edited, actor: by, remark: remark.presence, details: changes) if changes.any?
    end
    self
  end

  def admin_delete!(by:, remark:)
    raise Workflow::NotAllowed, "Only admin can do this" unless by.admin?
    raise Workflow::RemarkRequired, "Remark is required to delete" if remark.blank?
    transaction do
      tour_claim&.soft_delete!(by: by, remark: remark)
      soft_delete!(by: by, remark: remark)
      log_activity!(:deleted, actor: by, from: status, to: status, remark: remark)
      Notification.create!(user: user, actor: by, notifiable: self, kind: "tour_deleted", title: "Your tour was deleted by admin",
                           body: "#{reference_no} (#{duration_label}) – “#{remark}”", url: "/tours") unless by == user
    end
  end

  # Claim form: only after approval, and (for outstation tours) only after the tour's To-Date.
  def claim_open_on
    type_local? ? from_date : to_date + 1
  end

  def claimable?(today = Date.current)
    approved? && today >= claim_open_on
  end

  def duration_label
    type_local? ? claim_month.strftime("%b-%Y") : "#{from_date.strftime('%d/%m/%Y')} to #{to_date.strftime('%d/%m/%Y')}"
  end

  def days = (to_date - from_date).to_i + 1

  def to_s = reference_no

  private

  def transition!(to, by:, remark:)
    with_lock do
      from = status
      yield
      self.status = to
      save!
      log_activity!(to, actor: by, from: from, to: status, remark: remark)
      Notifier.tour(self, to, actor: by, remark: remark)
    end
    self
  end

  def log_created
    if draft?
      log_activity!(:saved_draft, actor: user, to: "draft", details: { from: from_date.to_s, to: to_date.to_s })
    elsif type_local?
      # Local mileage has no manager tour approval. Keep an auditable event,
      # but do not make the maker look like an approver in the history.
      log_activity!(:self_sanctioned, actor: user, from: "submitted", to: "approved")
    else
      log_activity!(:submitted, actor: user, to: "submitted", details: { from: from_date.to_s, to: to_date.to_s }.merge(approver_details))
      Notifier.tour(self, :submitted, actor: user) if type_tour?
    end
  end

  def approver_details = { l1: approver&.emp_code, l2: l2_approver&.emp_code, extra: approval_steps.map { |s| s.approver.emp_code }.presence }.compact

  def assign_approvers
    self.approver    = user.reporting_manager
    self.l2_approver = user.l2_manager unless user.l2_manager_id.nil? || user.l2_manager_id == user.reporting_manager_id
    assign_extra_steps
  end

  # Extra approvers of all modes used, in order (a person's highest position wins, e.g. COO 1 → Director 2);
  # skipped when that person is the employee or already L1 / L2.
  def assign_extra_steps
    chain = ExtraApprovalChain.build(extra_needs.map { |_visit, label, ch| [ label, ch ] }, skip: [ user_id, approver_id, l2_approver_id ])
    steps = chain.each_with_index.map { |(uid, reason), i| TourApprovalStep.new(approver_id: uid, position: i + 1, reason: reason) }
    self.approval_steps = steps
    self.l3_approver = nil
  end

  def prepare_new
    if ActiveModel::Type::Boolean.new.cast(send_now) || type_local?
      self.status = "submitted"
      self.submitted_at ||= Time.current
    else
      self.status = "draft"
    end
    assign_approvers if user && type_tour?
    if type_local? && user
      period = LocalMileagePeriod.new(user)
      self.claim_month = period.month
      self.from_date   = period.from_date
      self.to_date     = period.to_date
      # Local mileage plan is self-sanctioned; its money claim goes through approval.
      self.status      = "approved"
      self.approver    = user
      self.decided_by  = user
      self.approved_at = submitted_at
      self.l2_approver = nil
    end
  end

  def assign_reference_no
    self.id ||= self.class.connection.select_value("SELECT nextval('tours_id_seq')")
    prefix = type_local? ? "LM" : "TR"
    self.reference_no = format("%s-%d-%06d", prefix, from_date.year, id)
  end

  # A tour can be planned for any past month, but only up to the end of next month
  # (October → till 30-Nov, November → till 31-Dec).
  def self.latest_plan_date(today = Date.current) = today.next_month.end_of_month

  def within_plan_window
    last = self.class.latest_plan_date
    if (from_date && from_date > last) || (to_date && to_date > last)
      errors.add(:base, "Tour can be planned only till #{last.strftime('%d/%m/%Y')} (current and next month)")
    end
  end

  def date_order
    errors.add(:to_date, "must be on or after From-Date") if from_date && to_date && to_date < from_date
  end

  def visits_inside_range
    return unless from_date && to_date
    tour_visits.reject(&:marked_for_destruction?).each do |v|
      next if v.visit_date.nil? || v.visit_date.between?(from_date, to_date)
      errors.add(:base, "Visit date #{v.visit_date.strftime('%d/%m/%Y')} is outside the tour dates")
    end
  end

  def tour_needs_visits
    errors.add(:base, "Add at least one visit row") if tour_visits.reject(&:marked_for_destruction?).empty?
  end

  def no_overlap
    return unless user_id && from_date && to_date
    clash = Tour.type_tour.live.where(user_id: user_id).where.not(id: id)
                .where("from_date <= ? AND to_date >= ?", to_date, from_date).first
    errors.add(:base, "Overlaps your tour #{clash.reference_no} (#{clash.duration_label})") if clash
  end

  def one_local_per_month
    return unless user_id && claim_month
    if Tour.type_local.live.where(user_id: user_id, claim_month: claim_month).where.not(id: id).exists?
      errors.add(:base, "Local mileage claim for #{claim_month.strftime('%b-%Y')} already exists")
    end
  end

  def approver_present
    errors.add(:base, "L1 (reporting manager) is not set for you. Please contact PD HR.") if approver.nil?
  end
end
