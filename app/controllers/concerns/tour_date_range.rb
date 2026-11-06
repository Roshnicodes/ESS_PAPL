# "From date – To date" filter on tour lists: keeps the tours whose dates overlap the chosen range.
# Nothing picked = the list is exactly as before.
module TourDateRange
  extend ActiveSupport::Concern

  def set_tour_date_range
    @from_date = parse_range_day(params[:from])
    @to_date   = parse_range_day(params[:to])
    @from_date, @to_date = @to_date, @from_date if @from_date && @to_date && @to_date < @from_date
  end

  def within_tour_dates(scope)
    scope = scope.where("tours.to_date >= ?", @from_date) if @from_date
    scope = scope.where("tours.from_date <= ?", @to_date) if @to_date
    scope
  end

  private

  def parse_range_day(value)
    Date.parse(value.to_s) if value.present?
  rescue Date::Error, TypeError
    nil
  end
end
