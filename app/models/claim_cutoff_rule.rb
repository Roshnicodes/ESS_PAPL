# Local mileage month cutoff.
#   user_id NULL  -> rule for all employees (single row)
#   user_id set   -> override for that employee
# Only PD HR / admin manage these.
class ClaimCutoffRule < ApplicationRecord
  include Auditable

  DEFAULT_DAY = 5

  belongs_to :user, optional: true
  belongs_to :updated_by, class_name: "User"

  validates :cutoff_day, presence: true, numericality: { only_integer: true, in: 1..28 }
  validates :user_id, uniqueness: true, allow_nil: true
  validate  :single_global_rule, if: -> { user_id.nil? }

  scope :overrides, -> { where.not(user_id: nil) }

  after_save :audit

  def self.global
    find_by(user_id: nil)
  end

  def self.cutoff_day_for(user)
    where(user_id: [ user.id, nil ]).order(Arel.sql("user_id IS NULL")).pick(:cutoff_day) || DEFAULT_DAY
  end

  def global? = user_id.nil?

  private

  def single_global_rule
    scope = self.class.where(user_id: nil)
    scope = scope.where.not(id: id) if persisted?
    errors.add(:base, "A rule for all employees already exists") if scope.exists?
  end

  def audit
    change = saved_changes["cutoff_day"]
    log_activity!(saved_change_to_id? ? :cutoff_created : :cutoff_changed, actor: updated_by, remark: remark,
      details: { scope: global? ? "all_employees" : user&.emp_code, from_day: change&.first, to_day: cutoff_day })
  end
end
