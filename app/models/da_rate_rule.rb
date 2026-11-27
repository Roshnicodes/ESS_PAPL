# Special DA rate by position. Applies to the employees of one Level, one Designation or one Employee code, in one
# city or (city blank) in every city. Which rule wins when several fit:
#   employee code → designation → level, and inside each a city-specific rule before an "every city" one.
# No rule → the City & DA Rate master rate, as for everyone else.
class DaRateRule < ApplicationRecord
  TYPES = { "level" => "Level", "designation" => "Designation", "employee" => "Employee" }.freeze
  PRIORITY = %w[employee designation level].freeze

  belongs_to :city, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :match_type, inclusion: { in: TYPES.keys }
  validates :match_value, presence: true, length: { maximum: 150 }
  validates :da_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than: 100_000 }
  validates :remark, length: { maximum: 255 }
  validate  :unique_rule
  validate  :value_known

  before_validation { self.match_value = match_value.to_s.squish }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:match_type, :match_value, :city_id) }

  # "L - 5", "L-5" and "l 5" are the same level
  def self.norm(type, value)
    v = value.to_s.squish.downcase
    type.to_s == "level" ? v.delete(" ") : v
  end

  def self.keys_for(user)
    { "employee" => norm("employee", user.emp_code), "designation" => norm("designation", user.designation), "level" => norm("level", user.level) }
  end

  # Special rate for this employee in this city, or nil (= use the city's own rate)
  def self.rate_for(user, city)
    return nil if user.nil? || city.nil?
    keys = keys_for(user)
    rules = active.where(city_id: [ city.id, nil ]).to_a
    PRIORITY.each do |type|
      fitting = rules.select { |r| r.match_type == type && keys[type].present? && norm(type, r.match_value) == keys[type] }
      rule = fitting.find { |r| r.city_id == city.id } || fitting.find { |r| r.city_id.nil? }
      return rule.da_rate if rule
    end
    nil
  end

  # every city's rate for one employee – for the claim form (city dropdown carries the rate)
  def self.rates_for(user, cities)
    cities.to_h { |c| [ c.id, rate_for(user, c) || c.da_rate ] }
  end

  # the rule for this Level / Designation / Employee in this city (nil = "all cities"), if there is one
  def self.find_same(type, value, city_id)
    key = norm(type, value)
    where(match_type: type, city_id: city_id).to_a.find { |r| norm(type, r.match_value) == key }
  end

  # every rule (all its cities) of the same Level / Designation / Employee
  def self.group_of(rule)
    key = norm(rule.match_type, rule.match_value)
    where(match_type: rule.match_type).to_a.select { |r| norm(r.match_type, r.match_value) == key }
  end

  # What the form offers, from the active Employee List: { "level" => { key => { value:, label:, count: } }, ... }
  def self.choices
    users = User.active.pluck(:emp_code, :name, :designation, :level)
    by = ->(type, idx) {
      users.map { _1[idx] }.compact_blank.group_by { norm(type, _1) }
           .transform_values { |vals| { value: vals.first, label: vals.first, count: vals.size } }
           .sort_by { |_, v| v[:label].downcase }.to_h
    }
    {
      "level" => by.("level", 3),
      "designation" => by.("designation", 2),
      "employee" => users.sort_by { _1[1].to_s.downcase }
                         .to_h { |code, name, *| [ norm("employee", code), { value: code, label: "#{name} (#{code})", count: 1 } ] }
    }
  end

  def applies_to = "#{TYPES[match_type]}: #{match_value}"
  def city_label = city&.name || "All cities"

  private

  def unique_rule
    same = DaRateRule.where(match_type: match_type, city_id: city_id).where.not(id: id)
                     .select { |r| self.class.norm(match_type, r.match_value) == self.class.norm(match_type, match_value) }
    errors.add(:base, "A rule for #{applies_to} in #{city_label} already exists – edit that one") if same.any?
  end

  # the value must belong to at least one employee, so a typo cannot silently do nothing
  def value_known
    return if match_value.blank? || !TYPES.key?(match_type)
    column = { "level" => :level, "designation" => :designation, "employee" => :emp_code }[match_type]
    known = User.where.not(column => [ nil, "" ]).distinct.pluck(column).map { |v| self.class.norm(match_type, v) }
    errors.add(:match_value, "– no employee has #{TYPES[match_type].downcase} “#{match_value}”") unless known.include?(self.class.norm(match_type, match_value))
  end
end
