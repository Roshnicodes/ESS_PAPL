# FY (1 Apr – 31 Mar) + month filter shared by the claim lists and Payment Advice.
#
# A claim belongs to the month of its tour: Local Mileage uses the claim month it was
# raised for, an outstation tour uses its From-Date. Nothing is filtered unless the
# user actually picks a year / month, so the lists open exactly as they always did.
module ClaimPeriodFilter
  extend ActiveSupport::Concern

  PERIOD_SQL = "COALESCE(tours.claim_month, tours.from_date)".freeze

  included do
    helper_method :period_label if respond_to?(:helper_method)
  end

  def set_claim_period
    @month      = parse_month(params[:month])
    @fy         = FinancialYear.parse(params[:fy]) || (FinancialYear.for(@month) if @month)
    @month      = nil if @month && @fy && !@fy.covers?(@month)   # year changed – month list is stale
    @fy_options = FinancialYear.options
    @from_date  = parse_day(params[:from])
    @to_date    = parse_day(params[:to])
    @from_date, @to_date = @to_date, @from_date if @from_date && @to_date && @to_date < @from_date
  end

  # nil = no filter (everything), else the Date range to keep.
  def period_range
    # an exact From – To range wins over FY / month
    return (@from_date || Date.new(2000, 1, 1))..(@to_date || Date.new(2100, 1, 1)) if @from_date || @to_date
    return @month..@month.end_of_month if @month
    @fy&.range
  end

  # Subquery, never a join: the claim lists build their scopes with .or() chains and an
  # extra join there would change what those queries mean.
  def filter_by_period(scope)
    range = period_range or return scope
    scope.where(tour_id: Tour.with_deleted.where("#{PERIOD_SQL} BETWEEN ? AND ?", range.first, range.last).select(:id))
  end

  def period_label
    if @from_date || @to_date
      return [ @from_date&.strftime("%d/%m/%Y") || "start", @to_date&.strftime("%d/%m/%Y") || "today" ].join(" – ")
    end
    return @month.strftime("%b-%Y") if @month
    return "FY #{@fy.label}" if @fy
    "All months"
  end

  # "payment_advice_2026-27_oct" / "..._fy" / "..._all"
  def period_slug
    return "#{@from_date&.iso8601 || 'start'}_to_#{@to_date&.iso8601 || 'end'}" if @from_date || @to_date
    return "#{@fy.label}_#{@month.strftime('%b').downcase}" if @month
    return "fy_#{@fy.label}" if @fy
    "all"
  end

  private

  def parse_day(value)
    Date.parse(value.to_s) if value.present?
  rescue Date::Error, TypeError
    nil
  end

  def parse_month(value)
    text = value.to_s.strip
    return nil if text.blank?
    Date.strptime(text, "%Y-%m").beginning_of_month
  rescue Date::Error, TypeError
    nil
  end
end
