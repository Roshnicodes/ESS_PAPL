# An employee's bank account + passbook copy. Chosen on each claim; Finance pays into it.
# Once a sent claim uses an account its number/IFSC are locked (Finance must see what was chosen) –
# the employee can still remove it from future claims or add a new one.
class BankAccount < ApplicationRecord
  include Auditable

  TYPES = { savings: "savings", current: "current" }.freeze
  PASSBOOK_TYPES = %w[application/pdf image/jpeg image/png].freeze
  PASSBOOK_MAX = 5.megabytes
  LOCKED_FIELDS = %w[account_holder_name bank_name account_number ifsc_code].freeze

  enum :account_type, TYPES, prefix: true, validate: true

  belongs_to :user
  has_many :tour_claims, dependent: :restrict_with_error
  has_one_attached :passbook

  default_scope { where(deleted_at: nil) }
  scope :usable,  -> { where(active: true) }
  scope :ordered, -> { order(primary: :desc, created_at: :asc) }

  normalizes :account_number,      with: ->(v) { v.to_s.gsub(/\s+/, "") }
  normalizes :ifsc_code,           with: ->(v) { v.to_s.strip.upcase }
  normalizes :account_holder_name, :bank_name, :branch_name, with: ->(v) { v.to_s.squish.presence }

  attr_accessor :account_number_confirmation

  validates :account_holder_name, presence: true, length: { maximum: 150 }
  validates :bank_name,           presence: true, length: { maximum: 100 }
  validates :branch_name,         length: { maximum: 100 }
  validates :account_number, presence: true, format: { with: /\A\d{6,20}\z/, message: "must be 6–20 digits" },
                             uniqueness: { scope: :user_id, conditions: -> { where(deleted_at: nil) }, message: "is already added" }
  validates :account_number, confirmation: { message: "does not match" }, if: -> { account_number_confirmation }
  validates :ifsc_code, presence: true, format: { with: /\A[A-Z]{4}0[A-Z0-9]{6}\z/, message: "is not valid (e.g. SBIN0001234)" }
  validate  :passbook_present_and_valid
  validate  :locked_once_used, on: :update

  validate  :primary_must_be_active
  before_save :make_only_primary, if: -> { primary? && will_save_change_to_primary? }
  after_create_commit :become_primary_if_first

  def masked_number = "XXXX#{account_number.to_s.last(4)}"
  def label = "#{bank_name} · #{masked_number}#{' (Primary)' if primary?}"
  def to_s  = label

  def used_on_sent_claim?
    tour_claims.where.not(status: %w[draft]).exists?
  end

  # Employee can switch an account on/off any time. Off = not offered on new claims and removed from
  # unsent drafts; claims already sent keep it (Finance still sees where to pay).
  def toggle_active!
    transaction do
      if active?
        tour_claims.where(status: %w[draft returned]).update_all(bank_account_id: nil)
        Tour.where(bank_account_id: id, status: %w[draft returned]).update_all(bank_account_id: nil)
        update_columns(active: false, primary: false, updated_at: Time.current)
        BankAccount.where(user_id: user_id).usable.order(:created_at).first&.update_column(:primary, true) unless BankAccount.where(user_id: user_id, primary: true).exists?
      else
        update_columns(active: true, updated_at: Time.current)
        update_column(:primary, true) unless BankAccount.where(user_id: user_id, primary: true).exists?
      end
    end
  end

  private

  def passbook_present_and_valid
    return errors.add(:passbook, "copy is required") unless passbook.attached?
    errors.add(:passbook, "must be a PDF, JPG or PNG") unless passbook.blob.content_type.in?(PASSBOOK_TYPES)
    errors.add(:passbook, "must be smaller than 5 MB") if passbook.blob.byte_size > PASSBOOK_MAX
  end

  def locked_once_used
    changed_locked = LOCKED_FIELDS & changed
    return if changed_locked.empty? || !used_on_sent_claim?
    errors.add(:base, "This account is already used on a sent claim – its details cannot be changed. Add a new account instead.")
  end

  def primary_must_be_active
    errors.add(:primary, "account must be active") if primary? && !active?
  end

  def make_only_primary
    BankAccount.where(user_id: user_id).where.not(id: id).update_all(primary: false)
  end

  def become_primary_if_first
    update_column(:primary, true) if active? && !BankAccount.where(user_id: user_id, primary: true).exists?
  end
end
