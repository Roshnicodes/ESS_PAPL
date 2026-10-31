class TravelMode < ApplicationRecord
  include Auditable

  CATEGORIES = { own_vehicle: "own_vehicle", public: "public", office: "office", none: "none" }.freeze
  enum :category, CATEGORIES, prefix: true, validate: true

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  belongs_to :extra_approver, class_name: "User", optional: true   # legacy single L3 – now travel_mode_approvers
  has_many :mode_approvers, class_name: "TravelModeApprover", dependent: :delete_all
  has_many :chain_approvers, -> { where(travel_mode_approvers: { kind: "approve" }).order("travel_mode_approvers.position") }, through: :mode_approvers, source: :user
  has_many :watcher_users,   -> { where(travel_mode_approvers: { kind: "notify" }) }, through: :mode_approvers, source: :user
  has_many :mileage_rates, -> { order(effective_from: :desc) }, dependent: :restrict_with_error
  has_many :tour_visits, dependent: :restrict_with_error

  normalizes :name, with: ->(v) { v.to_s.squish }
  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 60 }
  validates :position, numericality: { only_integer: true }

  scope :active,       -> { where(active: true) }
  scope :ordered,      -> { order(:position, :name) }
  scope :tour_plan,    -> { active.where(for_tour_plan: true).ordered }
  scope :city_travel,  -> { active.where(for_city_travel: true).ordered }
  scope :local_travel, -> { active.where(for_local_travel: true).ordered }

  # Rate applicable on a given date (latest effective_from <= date).
  def rate_on(date = Date.current)
    return nil unless km_based?
    return mileage_rates.find { |r| r.effective_from <= date }&.rate_per_km if mileage_rates.loaded?   # ordered desc
    mileage_rates.where(effective_from: ..date).first&.rate_per_km
  end

  def current_rate = rate_on(Date.current)

  # extra approvers in order (after L1 → L2) and notify-only people
  def approver_chain = mode_approvers.select { |a| a.kind == "approve" }.sort_by(&:position)
  def watchers       = mode_approvers.select { |a| a.kind == "notify" }
  def tatkal_chain   = mode_approvers.select { |a| a.kind == "tatkal" }.sort_by(&:position)   # trains: Tatkal booking needs these
  def needs_extra_approval? = approver_chain.any?

  # replace the chain from the master form: ordered user ids for approval, user ids to notify
  def set_approvers!(approve_ids, notify_ids, tatkal_ids = nil)
    tatkal_ids = tatkal_chain.map(&:user_id) if tatkal_ids.nil?   # keep Tatkal approvers unless given
    transaction do
      mode_approvers.delete_all
      approve_ids.map(&:presence).compact.map(&:to_i).uniq.each_with_index { |uid, i| mode_approvers.create!(user_id: uid, kind: "approve", position: i + 1) }
      notify_ids.map(&:presence).compact.map(&:to_i).uniq.each { |uid| mode_approvers.create!(user_id: uid, kind: "notify", position: 1) }
      tatkal_ids.map(&:presence).compact.map(&:to_i).uniq.each_with_index { |uid, i| mode_approvers.create!(user_id: uid, kind: "tatkal", position: i + 1) }
      mode_approvers.reset
    end
  end

  def to_s = name
end
