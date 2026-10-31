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

  def active_for_authentication? = super && active?
  def inactive_message = active? ? super : :locked

  def display_name
    short_designation.present? ? "#{name}(#{short_designation})" : name
  end
  alias to_s display_name

  def hr?      = pd_hr? || admin?
  def finance? = pd_finance? || admin?

  private

  def password_required?
    !persisted? || password.present? || password_confirmation.present?
  end

  def manager_not_self
    errors.add(:reporting_manager, "cannot be the same employee") if persisted? && reporting_manager_id == id
    errors.add(:l2_manager, "cannot be the same employee") if persisted? && l2_manager_id == id
  end
end
