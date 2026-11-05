# Employee side: read the IOMs / Circulars addressed to them and open the attachments.
class CircularsController < ApplicationController
  before_action :set_circular, only: %i[show attachment]

  def index
    @circulars = scope.includes(:created_by).with_attached_attachments.newest_first.page(params[:page]).per(20)
  end

  def show
    mark_read
  end

  # Served through the app (never a public blob link) so only the addressed employees can open it.
  def attachment
    file = @circular.attachments.detect { |a| a.id == params[:attachment_id].to_i } or return head(:not_found)
    blob = file.blob
    send_data blob.download, filename: blob.filename.to_s, type: blob.content_type,
              disposition: params[:download] ? "attachment" : "inline"
  end

  private

  # Admin sees everything (including inactive ones, to check them); everyone else sees the
  # active ones addressed to them.
  def scope = current_user.admin? ? Circular.all : Circular.live.visible_to(current_user)

  def set_circular
    @circular = scope.with_attached_attachments.find(params[:id])
  end

  def mark_read
    current_user.notifications.unread.where(notifiable: @circular).update_all(read_at: Time.current)
  end
end
