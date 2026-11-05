# Indian financial year: 1 April – 31 March. FY "2026-27" runs 01-Apr-2026 … 31-Mar-2027.
# Used by the claim lists and Payment Advice so both read the same year everywhere.
class FinancialYear
  include Comparable

  # The month a tour belongs to: Local Mileage by its claim month, a tour by its From-Date.
  PERIOD_SQL = "COALESCE(claim_month, from_date)".freeze

  attr_reader :start_year

  def self.for(date)
    d = date.to_date
    new(d.month >= 4 ? d.year : d.year - 1)
  end

  def self.current(today = Date.current) = self.for(today)

  # Accepts "2026-27", "2026-2027" or "2026".
  def self.parse(value)
    year = value.to_s[/\A\s*(\d{4})/, 1] or return nil
    new(year.to_i)
  end

  # Every FY that has a tour / claim in it, newest first, always including this one.
  def self.options
    first, last = Tour.with_deleted.pick(Arel.sql("MIN(#{PERIOD_SQL})"), Arel.sql("MAX(#{PERIOD_SQL})"))
    years = [ current ]
    years << self.for(first) if first
    years << self.for(last)  if last
    (years.min..years.max).to_a.reverse
  end

  def initialize(start_year)
    @start_year = start_year.to_i
  end

  def label     = "#{start_year}-#{format('%02d', (start_year + 1) % 100)}"
  def to_param  = label
  def to_s      = label
  def from      = Date.new(start_year, 4, 1)
  def to        = Date.new(start_year + 1, 3, 31)
  def range     = from..to
  def covers?(date) = range.cover?(date.to_date)

  # April … March, as Date objects on the 1st of each month.
  def months = (0..11).map { |i| from >> i }

  def succ  = self.class.new(start_year + 1)
  def <=>(other) = start_year <=> (other.is_a?(self.class) ? other.start_year : other.to_i)
  def ==(other)  = other.is_a?(self.class) && start_year == other.start_year
  alias eql? ==
  def hash = start_year.hash
end
