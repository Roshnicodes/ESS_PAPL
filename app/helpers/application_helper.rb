module ApplicationHelper
  STATUS_COLORS = {
    "draft" => "bg-slate-100 text-slate-700 ring-slate-300/60",
    "submitted" => "bg-amber-50 text-amber-700 ring-amber-300/60",
    "l1_approved" => "bg-sky-50 text-sky-700 ring-sky-300/60",
    "l2_approved" => "bg-indigo-50 text-indigo-700 ring-indigo-300/60",
    "finance_query" => "bg-orange-50 text-orange-700 ring-orange-300/60",
    "extra_pending" => "bg-indigo-50 text-indigo-700 ring-indigo-300/60",
    "finance_pending" => "bg-violet-50 text-violet-700 ring-violet-300/60",
    "approved" => "bg-emerald-50 text-emerald-700 ring-emerald-300/60",
    "returned" => "bg-orange-50 text-orange-700 ring-orange-300/60",
    "rejected" => "bg-rose-50 text-rose-700 ring-rose-300/60",
    "cancelled" => "bg-slate-100 text-slate-500 ring-slate-300/60"
  }.freeze

  STATUS_LABELS = { "submitted" => "Pending L1", "draft" => "Prepared", "l1_approved" => "Forwarded to L2", "l2_approved" => "Forwarded for extra approval", "finance_pending" => "Forwarded to PD Finance", "finance_query" => "Finance query", "extra_pending" => "Extra approval" }.freeze

  # Tour badge. A Local Mileage is self-sanctioned the moment it is created, so it follows its claim:
  # "Prepared" until the claim is sent, then the claim's own stage (Pending L1 … Forwarded to PD Finance, Returned,
  # Rejected); "Approved" only once the claim itself is approved.
  def tour_status_badge(tour, label: nil)
    if tour.type_local? && tour.approved?
      claim = tour.tour_claim
      return status_badge("draft", label: "Prepared") if claim.nil? || claim.draft?
      return status_badge(claim.status) unless claim.approved?
    end
    label ||= "Plan approved" if tour.type_tour? && tour.approved?   # the plan, not its claim
    status_badge(tour.status, label: label)
  end

  def status_badge(status, label: nil)
    tag.span(label || STATUS_LABELS.fetch(status.to_s, status.to_s.humanize), class: "badge badge-dot #{STATUS_COLORS[status.to_s]}")
  end

  def dt(time)  = time&.strftime("%d/%m/%Y %I:%M %p")
  def d(date)   = date&.strftime("%d/%m/%Y")
  def inr(v)    = number_to_currency(v || 0, unit: "₹", precision: 2, delimiter: ",")

  # Reference numbers are internal audit identifiers.  Employees work with a
  # clear document type and its dates instead of a generated TR/LM ticket.
  def tour_type_label(tour)
    tour.type_local? ? "Local Mileage" : "Tour Plan"
  end

  def error_box(record)
    return unless record&.errors&.any?
    tag.div(class: "mb-5 flex gap-3 rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-800 fade-up") do
      icon(:warning, "h-5 w-5 shrink-0 text-rose-500") +
        tag.div do
          tag.div("Please fix the following:", class: "font-semibold mb-1") +
            tag.ul(safe_join(record.errors.full_messages.uniq.map { |m| tag.li(m) }), class: "list-disc pl-5 space-y-0.5")
        end
    end
  end

  def initials(user) = user.name.to_s.split.first(2).map { |w| w[0] }.join.upcase

  def avatar(user, size: "h-9 w-9 text-sm")
    palette = %w[from-brand-500 to-brand-700 from-leaf-500 to-emerald-600 from-violet-500 to-fuchsia-600 from-amber-400 to-orange-500 from-sky-400 to-cyan-600]
    pair = palette.each_slice(2).to_a[user.id.to_i % 5]
    tag.span(initials(user), class: "inline-flex shrink-0 items-center justify-center rounded-full bg-gradient-to-br #{pair.join(' ')} font-semibold text-white #{size}")
  end

  def page_header(title, subtitle = nil, icon_name: nil, &actions)
    tag.div(class: "page-heading mb-6 flex flex-wrap items-end justify-between gap-3 fade-up") do
      left = tag.div(class: "flex items-center gap-3") do
        (icon_name ? tag.span(icon(icon_name), class: "icon-chip bg-brand-600 text-white shadow-[var(--shadow-lift)]") : "".html_safe) +
          tag.div { tag.h1(title, class: "text-xl sm:text-2xl font-extrabold tracking-tight text-slate-900") + (subtitle ? tag.p(subtitle, class: "text-sm text-slate-500") : "".html_safe) }
      end
      left + (actions ? tag.div(capture(&actions), class: "page-heading-actions flex flex-wrap gap-2") : "".html_safe)
    end
  end

  def empty_row(cols, text = "No record found", icon_name: :inbox)
    tag.tr { tag.td(tag.div(icon(icon_name) + tag.span(text), class: "empty-state"), colspan: cols, class: "td-empty") }
  end

  # "L1 Rajesh Kumar → L2 Sunil Mehta" (L2 optional)
  # L1 → L2 → extra approvers (COO → Director …), shown only by designation
  def approver_chain(l1, l2, steps = [], final_label: nil)
    pill = ->(lvl, name, done = false) {
      tag.span(class: "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 ring-1 #{done ? 'bg-emerald-50 ring-emerald-200' : 'bg-white/70 ring-slate-200'}") do
        (lvl ? tag.span(lvl, class: "rounded bg-brand-600 px-1.5 text-[10px] font-bold text-white") : "".html_safe) + tag.span(name || "Not set", class: "text-sm font-medium text-slate-800") +
          (done ? icon(:check, "h-3.5 w-3.5 text-emerald-600") : "".html_safe)
      end
    }
    parts = [ pill.("L1", l1&.name) ]
    parts << pill.("L2", l2&.name) if l2
    Array(steps).each { |s| parts << pill.(nil, s.label, s.done?) }   # COO, Director – no L3 / L4 tag
    parts << tag.span(final_label, class: "text-sm font-medium text-slate-600") if final_label
    safe_join(parts, tag.span(" → ", class: "px-1 text-slate-400"))
  end

  # Single 🕒 icon used everywhere: opens the tour page (details + visits + full tour/claim history)
  def history_link(tour, css: "btn-light", **opts)
    link_to(tour, class: "#{css} btn-icon relative", title: "History", aria: { label: "History" }, **opts) { icon(:clock) }
  end

  def role_label(user) = { "pd_hr" => "PD HR", "pd_finance" => "PD Finance", "mis" => "MIS" }.fetch(user.role, user.role.humanize)

  ACTION_LABELS = {
    "submitted" => "Tour sent for approval", "approved" => "Tour approved", "self_sanctioned" => "Tour self-sanctioned",
    "cancelled" => "Tour cancelled", "claim_created" => "Claim form prepared", "claim_submitted" => "Claim sent",
    "claim_l1_approved" => "Claim forwarded by L1", "claim_l2_approved" => "Claim forwarded by L2", "l1_approved" => "Tour forwarded to L2 by L1", "l2_approved" => "Tour forwarded for extra approval", "extra_forwarded" => "Tour forwarded to next approver", "edited_resubmitted" => "Tour edited & sent again for approval",
    "it_tool_opened" => "Opened IT tool", "it_tool_settings_changed" => "IT Tools settings changed", "claim_extra_approved" => "Claim forwarded (extra approval)", "claim_query_sent" => "Finance query sent", "claim_query_replied" => "Finance query replied",
    "city_added" => "City added", "city_updated" => "City updated", "city_enabled" => "City enabled", "city_disabled" => "City disabled", "saved_draft" => "Tour saved (draft)", "claim_approved" => "Claim approved (PD Finance)",
    "claim_rejected" => "Claim rejected (final)", "claim_returned" => "Claim returned to employee", "returned" => "Tour returned to employee", "rejected" => "Tour rejected (final)", "claim_cancelled" => "Claim cancelled", "deduction_updated" => "Deductions updated", "admin_edited" => "Edited by admin", "deleted" => "Deleted by admin",
    "bank_added" => "Bank account added", "bank_updated" => "Bank account updated", "bank_activated" => "Bank account activated",
    "bank_deactivated" => "Bank account deactivated", "bank_primary" => "Primary bank account changed",
    "circular_created" => "IOM / Circular published", "circular_updated" => "IOM / Circular edited",
    "circular_notified" => "IOM / Circular notification sent", "circular_activated" => "IOM / Circular activated",
    "circular_deactivated" => "IOM / Circular deactivated",
    "payment_recorded" => "Payment UTR recorded", "payment_utr_corrected" => "Payment UTR corrected"
  }.freeze

  # Older local-mileage records used an "approved" activity with this remark.  It
  # was never a manager approval: local mileage plans are self-sanctioned.
  def self_sanction_log?(log)
    log.action == "self_sanctioned" ||
      (log.action == "approved" && log.remark == "Self-sanctioned local mileage")
  end

  # ---------- Printing ----------
  # The same Print button everywhere.  It never appears on the paper itself.
  def print_button(label = "Print", css: "btn-light")
    tag.button(type: "button", onclick: "window.print()", class: "#{css} print:hidden") { icon(:printer) + tag.span(label) }
  end

  # Rubber stamp put on a printed tour / claim: the word, who stamped it, when.
  SEALS = {
    "approved" => [ "Approved", "seal-ok" ],
    "draft" => [ "Not sent", "seal-wait" ],
    "submitted" => [ "Pending", "seal-wait" ],
    "l1_approved" => [ "Pending", "seal-wait" ],
    "l2_approved" => [ "Pending", "seal-wait" ],
    "finance_pending" => [ "Pending", "seal-wait" ],
    "finance_query" => [ "Pending", "seal-wait" ],
    "returned" => [ "Returned", "seal-warn" ],
    "rejected" => [ "Rejected", "seal-bad" ],
    "cancelled" => [ "Cancelled", "seal-void" ]
  }.freeze

  # A local mileage plan is self-sanctioned paperwork the moment it is created –
  # nobody approves it.  What actually goes L1 → L2 → PD Finance is its claim,
  # so that is what the stamp on a local mileage page has to follow.
  def tour_seal_record(tour) = tour.type_local? ? tour.tour_claim : tour

  # What a stamp is about – printed on its rim, so a "Tour Plan · Approved" stamp is never read as an approved claim.
  def seal_subject(record)
    return "Tour Plan" if record.is_a?(Tour)
    record.try(:type_local?) ? "Local Mileage" : "TA/DA Claim"
  end

  # Shown on screen and on the printed copy, at the foot of the document.
  def approval_seal(record, css: nil)
    return "".html_safe if record.nil?
    word, tone = SEALS[record.status.to_s]
    return "".html_safe unless word
    who, at = seal_signatory(record)
    tag.div(class: [ "seal", tone, css ]) do
      tag.div(class: "seal-ring") do
        tag.div(class: "seal-core") do
          tag.div(seal_subject(record), class: "seal-top") +
            tag.div(word, class: "seal-word") +
            (who.present? ? tag.div(who, class: "seal-line") : "".html_safe) +
            (at ? tag.div(d(at), class: "seal-line") : "".html_safe)
        end
      end
    end
  end

  # Whose stamp it is: the decider for a finished document, the stage it waits
  # at while it is still moving.  Extra approvers sign by designation.
  def seal_signatory(record)
    case record.status
    when "approved"
      return [ "Self-sanctioned", record.approved_at ] if record.try(:type_local?)
      step = record.try(:approval_steps)&.find { |s| s.approver_id == record.try(:decided_by_id) }
      [ seal_person(step&.label || record.try(:approved_by) || record.try(:decided_by)), record.approved_at ]
    when "rejected"  then [ seal_person(record.try(:rejected_by) || record.try(:decided_by)), record.rejected_at ]
    when "returned"  then [ seal_person(record.returned_by), record.returned_at ]
    when "cancelled" then [ seal_person(record.try(:cancelled_by)), record.cancelled_at ]
    else [ seal_waiting_with(record), nil ]
    end
  end

  # The stamp has no room for the "(JIT)" suffix display_name adds.
  def seal_person(value) = (value.is_a?(User) ? value.name : value.to_s).presence

  # Short line for a stamp that is still travelling – the circle has no room
  # for a whole stage_label.
  def seal_waiting_with(record)
    return "Saved only" if record.draft?
    if record.respond_to?(:current_approver)   # tour: L1 → L2 → extra approvers
      name = record.l2_approved? ? record.l3_label : record.current_approver&.name
    else                                       # claim: L1 → L2 → PD Finance
      name = { "submitted" => record.l1_approver&.name, "l1_approved" => record.l2_approver&.name,
               "finance_pending" => "PD Finance", "finance_query" => "Finance query" }[record.status]
    end
    name && "with #{name}"
  end

  def history_log_visible?(log, logs)
    # Nobody sanctions a local mileage plan – it is paperwork the employee
    # opens.  The event stays in the audit trail, off the shown history.
    return false if self_sanction_log?(log)
    return true unless log.action == "submitted" && log.trackable_type == "Tour"

    # Hide the legacy "sent" entry only when its tour has the paired
    # self-sanction event. Normal tour submissions always stay visible.
    !logs.any? { |entry| entry.trackable_type == "Tour" && entry.trackable_id == log.trackable_id && self_sanction_log?(entry) }
  end

  APPROVAL_ACTIONS = %w[approved l1_approved l2_approved claim_l1_approved claim_l2_approved claim_approved].freeze

  def history_actor_label(log)
    return nil if self_sanction_log?(log)
    owner = log.trackable.respond_to?(:user_id) ? log.trackable.user_id : nil
    return nil if log.action.in?(APPROVAL_ACTIONS) && owner && log.actor_id == owner   # never "approved by <maker>"
    if log.trackable.is_a?(Tour) && (step = log.trackable.approval_steps.find { |s| s.approver_id == log.actor_id })
      return step.label   # extra approvers (COO, Director) shown by designation
    end

    log.actor&.name || "System"
  end

  def history_remark(log)
    # Remarks remain part of the audit record but are intentionally not shown
    # in the compact history.  The only exception is a deduction's line item,
    # exposed separately below so employees can see what was reduced.
    nil
  end

  def history_deduction_details(log)
    return [] unless log.action == "deduction_updated"

    Array(log.details&.fetch("lines", [])).filter_map do |change|
      deduction = Array(change["deduction"]).last.to_d
      next unless deduction.positive?

      item = change["item"].presence || change["section"].to_s.humanize
      "#{item}: −#{inr(deduction)}"
    end
  end

  def action_label(log)
    return "Self-sanctioned" if self_sanction_log?(log)

    ACTION_LABELS.fetch(log.action, log.action.humanize)
  end
end
