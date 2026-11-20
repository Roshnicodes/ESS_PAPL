class User < ApplicationRecord
  include Auditable

  devise :database_authenticatable, :rememberable, :trackable

  ROLES = {
    employee: "employee",
    mis: "mis",
    pd_hr: "pd_hr",
    pd_finance: "pd_finance",
    admin: "admin"
  }.freeze
  PASSWORD_MINIMUM_LENGTH = 3
  enum :role, ROLES, default: :employee, validate: true

  belongs_to :location, optional: true
  belongs_to :reporting_manager, class_name: "User", optional: true
  belongs_to :l2_manager,        class_name: "User", optional: true   # Functional manager (L-2)
  belongs_to :finance_approver,  class_name: "User", optional: true   # PD Finance for this employee's claims (set by HR)
  has_many   :notifications, -> { recent }, dependent: :delete_all
  has_many   :subordinates, class_name: "User", foreign_key: :reporting_manager_id, dependent: :restrict_with_error
  has_many   :tours, dependent: :restrict_with_error
  has_many   :tour_claims, dependent: :restrict_with_error
  has_many   :bank_accounts, dependent: :restrict_with_error
  has_one    :claim_cutoff_rule, dependent: :destroy

  normalizes :emp_code, with: ->(v) { v.to_s.strip.upcase }
  normalizes :email,    with: ->(v) { v.to_s.strip.downcase.presence }

  validates :emp_code, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 30 }
  validates :email, uniqueness: { case_sensitive: false }, allow_nil: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 150 }
  # HR's existing employee-password sheet includes three- and four-character
  # passwords, so keep the application rule aligned with that approved list.
  validates :password, presence: true, length: { minimum: PASSWORD_MINIMUM_LENGTH }, confirmation: true, if: :password_required?
  validate  :manager_not_self
  validate  :not_deactivating_an_approver, if: -> { persisted? && will_save_change_to_active?(from: true, to: false) }

  after_update_commit :reassign_pending_finance_claims!, if: :saved_change_to_finance_approver_id?

  scope :active,  -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  # HR changed this employee's Finance person → claims already waiting at finance move to the new person
  def reassign_pending_finance_claims!
    return if finance_approver_id.nil?
    tour_claims.where(status: "finance_pending").where.not(finance_approver_id: finance_approver_id)
               .update_all(finance_approver_id: finance_approver_id, updated_at: Time.current)
  end

  # ---- who sees the Approvals menus ------------------------------------------
  # L1 / L2 of anyone, L3 of a travel mode (e.g. Flight), or something is pending with / was approved by them
  def tour_approver?
    return @tour_approver if defined?(@tour_approver)
    @tour_approver = hr? || admin? ||
      User.active.where(reporting_manager_id: id).or(User.active.where(l2_manager_id: id)).exists? ||
      TravelModeApprover.where(user_id: id, kind: %w[approve tatkal]).exists? ||
      Tour.pending_for(self).exists?
  end

  # L1 / L2 of anyone, Finance person of anyone, PD Finance / HR / admin
  def claim_approver?
    return @claim_approver if defined?(@claim_approver)
    @claim_approver = finance? || hr? ||
      TravelModeApprover.where(user_id: id, kind: %w[approve tatkal]).exists? ||
      User.active.where(reporting_manager_id: id).or(User.active.where(l2_manager_id: id)).or(User.active.where(finance_approver_id: id)).exists? ||
      TourClaim.in_queue_of(self).exists?
  end

  # Active employees for whom this person is the L-1, L-2 or Finance approver
  def approval_dependents
    User.active.where.not(id: id)
        .where("reporting_manager_id = :id OR l2_manager_id = :id OR finance_approver_id = :id", id: id).ordered
  end

  # Travel modes (e.g. Flight) where this person must approve tours
  def approver_travel_modes
    TravelMode.where(id: TravelModeApprover.where(user_id: id, kind: %w[approve tatkal]).select(:travel_mode_id))
  end

  # Tour plans / claims waiting for this person's own decision (the Approvals queues). Claims in
  # the common PD Finance pool (no named Finance person) are left out – any PD Finance can settle them.
  def pending_approval_tours = Tour.pending_for(self)
  def pending_approval_claims
    queue = TourClaim.in_queue_of(self)
    queue.where.not(status: "finance_pending").or(queue.where.not(finance_approver_id: nil))
  end

  def active_for_authentication? = super && active?
  def inactive_message = active? ? super : :locked

  def display_name
    short_designation.present? ? "#{name}(#{short_designation})" : name
  end
  alias to_s display_name

  def hr?      = pd_hr? || admin?
  def finance? = pd_finance? || admin?

  # Anyone who actually settles claims: the PD Finance role / admin, plus a person HR has
  # named as the Finance approver on at least one employee – their role is often plain
  # "employee", but every claim of those employees ends with them.
  def finance_person?
    return @finance_person if defined?(@finance_person)
    @finance_person = finance? || User.where(finance_approver_id: id).exists?
  end

  private

  def password_required?
    !persisted? || password.present? || password_confirmation.present?
  end

  # HR may not deactivate someone who is still an approval authority – tours / claims of those
  # employees would get stuck. Set a new L-1 / L-2 / Finance for them first, then deactivate.
  def not_deactivating_an_approver
    people = approval_dependents.to_a
    modes = approver_travel_modes.pluck(:name)
    tours = pending_approval_tours.includes(:user).order(:submitted_at).to_a
    claims = pending_approval_claims.includes(:user).order(:submitted_at).to_a
    return if people.empty? && modes.empty? && tours.empty? && claims.empty?

    if people.any?
      names = people.first(10).map do |p|
        roles = { "L-1" => p.reporting_manager_id, "L-2" => p.l2_manager_id, "Finance" => p.finance_approver_id }
                  .select { |_, v| v == id }.keys
        "#{p.name} (#{p.emp_code}) – #{roles.join(' / ')}"
      end
      names << "and #{people.size - 10} more" if people.size > 10
      errors.add(:base, "Cannot deactivate #{name}: they are the approval authority for #{people.size} active " \
                        "employee#{'s' unless people.size == 1}: #{names.join('; ')}. " \
                        "First set a new L-1 / L-2 / Finance approver for #{people.size == 1 ? 'this employee' : 'these employees'}, then deactivate.")
    end
    if modes.any?
      errors.add(:base, "Cannot deactivate #{name}: they are an approver for travel mode #{modes.join(', ')}. " \
                        "Remove them from Masters → Travel Modes first.")
    end
    if tours.any? || claims.any?
      items = tours.map { |t| "#{t.type_local? ? 'Local mileage plan' : 'Tour plan'} of #{t.user.name} (#{t.user.emp_code})" } +
              claims.map { |c| "#{c.type_local? ? 'Local mileage claim' : 'TA/DA claim'} of #{c.user.name} (#{c.user.emp_code})" }
      list = items.first(10)
      list << "and #{items.size - 10} more" if items.size > 10
      counts = [ (tours.any? ? "#{tours.size} tour plan#{'s' unless tours.size == 1}" : nil),
                 (claims.any? ? "#{claims.size} claim#{'s' unless claims.size == 1}" : nil) ].compact.join(" and ")
      errors.add(:base, "Cannot deactivate #{name}: #{counts} still pending with them for approval: #{list.join('; ')}. " \
                        "They must approve / reject (or answer) these first, then deactivate.")
    end
  end

  def manager_not_self
    errors.add(:reporting_manager, "cannot be the same employee") if persisted? && reporting_manager_id == id
    errors.add(:l2_manager, "cannot be the same employee") if persisted? && l2_manager_id == id
  end
end
