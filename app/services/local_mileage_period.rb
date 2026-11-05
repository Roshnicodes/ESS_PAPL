# Decides which month an employee may raise a Local Mileage claim for, and how long
# a claim for a month may still be SENT.
#
# Rule (cutoff day C, default 5, editable by PD HR globally or per employee):
#   on or before day C of a month -> previous month is still shown (late claims allowed)
#   after day C                   -> current month is shown
#
# e.g. C = 5:  03-Nov -> Oct-2026,  06-Nov -> Nov-2026
#
# The same day closes the month for good: a claim of month M must reach L1 on or
# before day C of the next month. An October claim saved but never sent is therefore
# dead from 06-Nov (C = 5) – the employee is told so instead of silently failing.
class LocalMileagePeriod
  attr_reader :user, :today

  def initialize(user, today: Date.current)
    @user  = user
    @today = today
  end

  def cutoff_day
    @cutoff_day ||= ClaimCutoffRule.cutoff_day_for(user)
  end

  def month
    today.day > cutoff_day ? today.beginning_of_month : today.prev_month.beginning_of_month
  end

  def from_date = month
  def to_date   = month.end_of_month
  def label     = month.strftime("%b-%Y")

  # Last date on which a claim for `claim_month` may be sent for approval:
  # the cutoff day of the following month (clamped, so day 31 never overflows).
  def deadline_for(claim_month)
    nxt = claim_month.to_date.beginning_of_month.next_month
    nxt + [ cutoff_day, nxt.end_of_month.day ].min - 1
  end

  # True once that month can no longer be sent.
  def closed?(claim_month) = today > deadline_for(claim_month)

  # Message shown on the form and returned as a validation error.
  def closed_message(claim_month)
    "Local mileage for #{claim_month.to_date.strftime('%b-%Y')} can no longer be filled or sent – " \
    "the last date was #{deadline_for(claim_month).strftime('%d/%m/%Y')} (cutoff day #{cutoff_day} of the next month). " \
    "Please contact PD HR."
  end

  def already_claimed?
    return @already_claimed if defined?(@already_claimed)
    @already_claimed = user.tours.type_local.live.exists?(claim_month: month)
  end
end
