# Every state change / important edit writes an immutable ActivityLog row with exact time.
module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :activity_logs, -> { chronological }, as: :trackable, dependent: :restrict_with_exception
  end

  def log_activity!(action, actor: Current.user, from: nil, to: nil, remark: nil, details: {})
    activity_logs.create!(
      action: action.to_s,
      actor: actor,
      from_status: from,
      to_status: to,
      remark: remark.presence,
      details: details,
      ip_address: Current.ip_address
    )
  end
end
