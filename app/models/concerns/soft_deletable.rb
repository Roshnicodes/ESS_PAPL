# Admin delete keeps the row (and its audit trail) but hides it everywhere.
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    default_scope { where(deleted_at: nil) }
    belongs_to :deleted_by, class_name: "User", optional: true
    scope :with_deleted, -> { unscope(where: :deleted_at) }
    scope :only_deleted, -> { with_deleted.where.not(deleted_at: nil) }
  end

  def deleted? = deleted_at.present?

  def soft_delete!(by:, remark:)
    raise Workflow::RemarkRequired, "Remark is required to delete" if remark.blank?
    update_columns(deleted_at: Time.current, deleted_by_id: by.id, delete_remark: remark, updated_at: Time.current)
  end
end
