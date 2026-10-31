# Admin-editable settings (IT Tools links). Secret values are encrypted with a key derived from the
# app's secret_key_base, so the database never holds them in plain text. ENV always wins over the table.
class AppSetting < ApplicationRecord
  SECRET_KEYS = %w[KRA_SSO_SECRET GEOHUB_SSO_SECRET OLD_ESS_SSO_SECRET].freeze

  belongs_to :updated_by, class_name: "User", optional: true
  validates :key, presence: true, uniqueness: true, length: { maximum: 100 }

  def self.get(key)
    env = ENV[key].presence and return env
    row = Rails.cache.fetch("app_setting/#{key}", expires_in: 1.minute) { find_by(key: key)&.value }
    return nil if row.blank?
    key.in?(SECRET_KEYS) ? encryptor.decrypt_and_verify(row) : row
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def self.set!(key, value, by:)
    rec = find_or_initialize_by(key: key)
    rec.value = value.blank? ? nil : (key.in?(SECRET_KEYS) ? encryptor.encrypt_and_sign(value.to_s.strip) : value.to_s.strip)
    rec.updated_by = by
    rec.save!
    Rails.cache.delete("app_setting/#{key}")
    rec
  end

  def self.present?(key) = get(key).present?

  def self.encryptor
    key = Rails.application.key_generator.generate_key("ess app settings", ActiveSupport::MessageEncryptor.key_len)
    ActiveSupport::MessageEncryptor.new(key)
  end
end
