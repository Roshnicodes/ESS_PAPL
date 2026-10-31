# Decides which month an employee may raise a Local Mileage claim for.
#
# Rule (cutoff day C, default 5, editable by PD HR globally or per employee):
#   on or before day C of a month -> previous month is still shown (late claims allowed)
#   after day C                   -> current month is shown
#
# e.g. C = 5:  03-Nov -> Oct-2026,  06-Nov -> Nov-2026
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

  def already_claimed?
    return @already_claimed if defined?(@already_claimed)
    @already_claimed = user.tours.type_local.live.exists?(claim_month: month)
  end
end
