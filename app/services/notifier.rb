# Who gets a bell notification for each tour / claim action.
#
# Tour:  sent → L1 · forwarded by L1 → employee + L2 · approved → employee (+ L1 if L2 approved)
#        returned / rejected → employee (+ L1 if done by L2) · cancelled → approvers involved
# Claim: sent → L1 · forwarded by L1 → employee + L2 · forwarded to finance → employee + PD Finance
#        approved → employee + L1 + L2 · returned / rejected → employee + earlier approvers · cancelled → approvers
class Notifier
  include Rails.application.routes.url_helpers

  def self.tour(tour, event, actor:, remark: nil) = new.tour(tour, event, actor, remark)
  def self.claim(claim, event, actor:, remark: nil) = new.claim(claim, event, actor, remark)

  def tour(t, event, actor, remark)
    ref = "#{t.type_local? ? 'Local mileage' : 'Tour plan'} (#{t.duration_label})"
    emp = t.user
    step_of_actor = actor && t.approval_steps.find { |s| s.approver_id == actor.id }
    by  = step_of_actor ? step_of_actor.label : actor&.name   # extra approvers by designation
    case event.to_sym
    when :submitted
      push t.approver, t, actor, :tour_pending, "Tour for your approval (L1)", "#{emp.name} sent #{ref}", approvals_tour_path(t)
    when :l1_approved
      push emp, t, actor, :tour_forwarded, "Your tour was forwarded to L2", "#{by} forwarded #{ref} to #{t.l2_approver&.name}", tour_path(t), remark
      push t.l2_approver, t, actor, :tour_pending, "Tour for your approval (L2)", "#{emp.name} · #{ref} – forwarded by #{by}", approvals_tour_path(t), remark
    when :l2_approved, :extra_forwarded
      why  = t.extra_reason ? " · uses #{t.extra_reason}" : ""
      push emp, t, actor, :tour_forwarded, "Your tour was forwarded to #{t.l3_label}", "#{by} forwarded #{ref} to #{t.l3_label}", tour_path(t), remark
      push t.l3_approver, t, actor, :tour_pending, "Tour for your approval#{" (#{t.extra_reason})" if t.extra_reason}",
           "#{emp.name} · #{ref}#{why} – forwarded by #{by}", approvals_tour_path(t), remark
    when :approved
      return if t.type_local?
      claim_when = t.claimable? ? "Make the claim now." : "Claim form opens on #{t.claim_open_on.strftime('%d/%m/%Y')}."
      push emp, t, actor, :tour_approved, "Your tour is approved – make the claim", "#{ref} approved by #{by}. #{claim_when}", tours_path, remark
      earlier_tour_approvers(t, actor).each { |u| push u, t, actor, :tour_approved, "Tour approved by #{level_of(t, actor)}", "#{emp.name} · #{ref} approved by #{by}", tour_path(t), remark }
      # notify-only people of the modes used (e.g. Administration for Personal Four Wheeler) – information, no action
      t.used_modes.each do |m|
        m.watchers.each do |w|
          push w.user, t, actor, :tour_info, "FYI: #{emp.name} will use #{m.name}",
               "#{ref} – approved tour plan of #{emp.name} (#{emp.emp_code}) uses #{m.name}", tour_path(t)
        end
      end
    when :returned
      push emp, t, actor, :tour_returned, "Your tour was returned", "#{by} returned #{ref} – correct and send again", edit_tour_path(t), remark
      earlier_tour_approvers(t, actor).each { |u| push u, t, actor, :tour_returned, "Tour returned by #{level_of(t, actor)}", "#{emp.name} · #{ref} returned by #{by}", tour_path(t), remark }
    when :rejected
      push emp, t, actor, :tour_rejected, "Your tour was rejected", "#{ref} rejected by #{by}", tour_path(t), remark
      earlier_tour_approvers(t, actor).each { |u| push u, t, actor, :tour_rejected, "Tour rejected by #{level_of(t, actor)}", "#{emp.name} · #{ref} rejected by #{by}", tour_path(t), remark }
    when :cancelled
      [ t.approver, (t.l2_approver if t.status_before_cancel.in?(%w[l1_approved l2_approved approved])),
        (t.l3_approver if t.status_before_cancel.in?(%w[l2_approved approved])) ].compact.uniq.each do |u|
        push u, t, actor, :tour_cancelled, "Tour cancelled by employee", "#{emp.name} cancelled #{ref}", tour_path(t), remark
      end
    end
  end

  # approvers who already acted before the one acting now (L1, L2 who forwarded)
  def earlier_tour_approvers(t, actor)
    ([ t.l1_approved_by, t.l2_approved_by ] + t.approval_steps.select(&:done?).map(&:acted_by)).compact.uniq - [ actor ]
  end

  def level_of(t, actor)
    step = t.approval_steps.find { |s| s.approver_id == actor&.id }
    return step.label if step
    { t.l2_approver_id => "L2", t.approver_id => "L1" }.compact.fetch(actor&.id, "approver")
  end

  def claim(c, event, actor, remark)
    t = c.tour
    ref = "Claim (#{t.duration_label} · #{inr(c.grand_total)})"
    emp = c.user
    by  = actor&.name
    case event.to_sym
    when :claim_submitted
      push c.l1_approver, c, actor, :claim_pending, "Claim for your approval (L1)", "#{emp.name} sent #{ref}", approvals_claim_path(c)
    when :claim_l1_approved, :claim_l2_approved, :claim_extra_approved
      if c.l1_approved?
        push emp, c, actor, :claim_forwarded, "Your claim was forwarded to L2", "#{by} forwarded #{ref}", tour_claim_path(t), remark
        push c.l2_approver, c, actor, :claim_pending, "Claim for your approval (L2)", "#{emp.name} · #{ref} – forwarded by #{by}", approvals_claim_path(c), remark
      elsif c.extra_pending?
        why = c.extra_reason ? " (#{c.extra_reason})" : ""
        push emp, c, actor, :claim_forwarded, "Your claim was forwarded to #{c.extra_label}", "#{by} forwarded #{ref}", tour_claim_path(t), remark
        push c.extra_approver, c, actor, :claim_pending, "Claim for your approval#{why}", "#{emp.name} · #{ref} – forwarded by #{by}", approvals_claim_path(c), remark
      else
        push emp, c, actor, :claim_forwarded, "Your claim was forwarded to PD Finance", "#{by} forwarded #{ref}", tour_claim_path(t), remark
        finance_people(c).each { |u| push u, c, actor, :claim_pending, "Claim for final approval", "#{emp.name} · #{ref} – forwarded by #{by}", approvals_claim_path(c), remark }
      end
    when :claim_approved
      push emp, c, actor, :claim_approved, "Your claim is approved", "#{ref} approved by #{by}", tour_claim_path(t), remark
      # Local Mileage: notify-only people of the modes used (e.g. Administration for Four Wheeler)
      if c.type_local?
        c.claim_local_travels.filter_map(&:travel_mode).uniq.each do |m|
          m.watchers.each { |w| push w.user, c, actor, :claim_info, "FYI: #{emp.name} used #{m.name}", "Local mileage #{ref} of #{emp.name} (#{emp.emp_code}) – #{m.name}", notifications_path }
        end
      end
      [ c.l1_approver, c.l2_approver ].compact.uniq.each { |u| push u, c, actor, :claim_approved, "Claim approved by PD Finance", "#{emp.name} · #{ref}", approvals_claim_path(c) }
    when :claim_query_sent
      q = c.open_query
      push q&.asked_to, c, actor, :claim_query, "Finance query on a claim – reply needed", "#{emp.name} · #{ref} – #{by} asks", approvals_claim_path(c), remark
      push emp, c, actor, :claim_query_info, "Finance asked #{q&.role_label} about your claim", "#{ref} – waiting for reply from #{q&.asked_to&.name}", tour_claim_path(t)
    when :claim_query_replied
      q = c.claim_queries.reject(&:open?).last
      push q&.asked_by, c, actor, :claim_pending, "Reply received – claim back for approval", "#{emp.name} · #{ref} – #{by} replied", approvals_claim_path(c), remark
    when :claim_returned, :claim_rejected
      returned = event.to_sym == :claim_returned
      push emp, c, actor, :"claim_#{returned ? 'returned' : 'rejected'}", "Your claim was #{returned ? 'returned' : 'rejected'}",
           "#{ref} #{returned ? 'returned – correct and send again' : 'rejected'} by #{by}", returned ? edit_tour_claim_path(t) : tour_claim_path(t), remark
      earlier = [ c.l1_approver, (c.l2_approver if c.l2_approved_at || c.finance_pending? || actor&.finance?) ].compact.uniq - [ actor ]
      earlier.each { |u| push u, c, actor, :claim_closed, "Claim #{returned ? 'returned' : 'rejected'}", "#{emp.name} · #{ref} by #{by}", approvals_claim_path(c), remark }
    end
  end

  private

  def finance_people(c)
    c.finance_approver ? [ c.finance_approver ] : User.active.where(role: %w[pd_finance]).to_a
  end

  def push(user, notifiable, actor, kind, title, body, url, remark = nil)
    return if user.nil? || user == actor
    body = "#{body} – “#{remark}”" if remark.present?
    Notification.create!(user: user, actor: actor, notifiable: notifiable, kind: kind.to_s, title: title.first(200), body: body, url: url)
  end

  def inr(v) = ActiveSupport::NumberHelper.number_to_currency(v || 0, unit: "₹", precision: 2, delimiter: ",")
end
