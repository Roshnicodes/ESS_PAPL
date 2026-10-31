# Simple "name" masters (Project, Budget line item, Budget line item code, City, Location).
# Case-insensitive unique; supports suggestions + add-new-on-the-fly.
module NameMaster
  extend ActiveSupport::Concern

  included do
    normalizes :name, with: ->(v) { v.to_s.squish }
    validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 500 }
    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:name) }
    scope :suggest, ->(q) {
      q = q.to_s.squish
      q.blank? ? active.ordered.limit(20) : active.where("name ILIKE ?", "%#{sanitize_sql_like(q)}%").ordered.limit(20)
    }
  end

  class_methods do
    # Returns existing (case-insensitive) or creates a new one.
    def fetch_or_create!(name, by: Current.user)
      name = name.to_s.squish
      return nil if name.blank?
      where("lower(name) = ?", name.downcase).first || create!(name: name, **creator_attrs(by))
    rescue ActiveRecord::RecordNotUnique
      where("lower(name) = ?", name.downcase).first!
    end

    def creator_attrs(by)
      column_names.include?("created_by_id") ? { created_by: by } : {}
    end
  end

  def to_s = name
end
