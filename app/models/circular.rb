# IOM / Circular published by the administrator.
#
#   Topic type (IOM or Circular) → Topic → any number of attachments (PDF, Word, Excel,
#   image, anything) → who is told (all employees, or a chosen list) → Save.
#
# Everyone in the audience gets a bell notification, which krai also delivers as an
# email (same relay as tour / claim notifications). Deactivating one hides it from
# employees and stops it appearing in their list – nothing is deleted.
class Circular < ApplicationRecord
  include Auditable

  TYPES     = { iom: "iom", circular: "circular" }.freeze
  AUDIENCES = { all: "all", selected: "selected" }.freeze
  # Every file type is accepted. The only limit is a per-file size, so one upload
  # cannot fill the server's disk.
  ATTACHMENT_MAX = 25.megabytes

  enum :topic_type, TYPES, prefix: :type, validate: true
  enum :audience, AUDIENCES, prefix: :to, validate: true

  belongs_to :created_by, class_name: "User"
  # autosave: the admin form rebuilds this list on every edit, and without it
  # mark_for_destruction on a removed employee would be ignored on save.
  has_many :circular_recipients, autosave: true, dependent: :delete_all
  has_many :recipients, through: :circular_recipients, source: :user
  has_many_attached :attachments

  validates :topic, presence: true, length: { maximum: 200 }
  validates :description, length: { maximum: 5000 }
  validate  :attachment_sizes
  validate  :selected_audience_has_people

  scope :live,         -> { where(active: true) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :visible_to,   ->(user) {
    where(audience: "all").or(where(id: CircularRecipient.where(user_id: user.id).select(:circular_id)))
  }

  # "All employees" is resolved when the notification is sent, so people added to the
  # Employee List after it was written are included in a re-send.
  def audience_users
    to_all? ? User.active.ordered : recipients.where(active: true).order(:name)
  end

  def audience_label = to_all? ? "All employees" : "#{circular_recipients.size} selected employee(s)"
  def type_label     = type_iom? ? "IOM" : "Circular"
  def to_s           = "#{type_label}: #{topic}"
  def notified?      = notified_at.present?

  # Bell notification for every recipient; Notification's own callback mails it through krai.
  # Called from CircularNotifyJob so a list of hundreds does not hold up the admin's request.
  def notify!(by: created_by)
    people = audience_users.to_a
    now = Time.current
    people.each do |u|
      Notification.create!(user: u, actor: by, notifiable: self, kind: "circular_published",
                           title: "#{type_label}: #{topic}".first(200), body: mail_body, url: path)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Circular #{id}: could not notify user=#{u.id}: #{e.message}")
    end
    circular_recipients.update_all(notified_at: now) if to_selected?
    update_columns(notified_at: now, notified_count: people.size, updated_at: now)
    log_activity!(:circular_notified, actor: by, details: { recipients: people.size, audience: audience })
    people.size
  end

  def path = Rails.application.routes.url_helpers.circular_path(self)

  def mail_body
    [ description.to_s.squish.truncate(400).presence,
      ("#{attachments.size} attachment#{"s" unless attachments.size == 1}: #{attachments.map { |a| a.filename.to_s }.join(', ')}" if attachments.attached?),
      "Open ESS to read it." ].compact.join(" | ")
  end

  private

  def attachment_sizes
    attachments.each do |a|
      next if a.byte_size <= ATTACHMENT_MAX
      errors.add(:attachments, "“#{a.filename}” is larger than #{ATTACHMENT_MAX / 1.megabyte} MB")
    end
  end

  def selected_audience_has_people
    errors.add(:base, "Choose at least one employee, or select “All employees”") if to_selected? && circular_recipients.reject(&:marked_for_destruction?).empty?
  end
end
