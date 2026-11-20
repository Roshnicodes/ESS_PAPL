# Employee side: read the IOMs / Circulars addressed to them and open the attachments.
class CircularsController < ApplicationController
  include ListSearch
  before_action :set_circular, only: %i[show attachment]

  def index
    @circulars = search_columns(scope, %w[circulars.topic circulars.description circulars.topic_type])
                   .includes(:created_by).with_attached_attachments.newest_first.page(params[:page]).per(20)
  end

  def show
    mark_read
  end

  # Served through the app (never a public blob link) so only the addressed employees can open it.
  def attachment
    file = @circular.attachments.detect { |a| a.id == params[:attachment_id].to_i } or return head(:not_found)
    blob = file.blob
    # only pictures and PDFs open in the browser (shown on the IOM page); anything else always downloads,
    # so an uploaded HTML / SVG file can never run inside ESS
    viewable = blob.content_type.to_s == "application/pdf" ||
               (blob.content_type.to_s.start_with?("image/") && !blob.content_type.to_s.include?("svg"))
    expires_in 1.hour, private: true
    send_data blob.download, filename: blob.filename.to_s, type: blob.content_type,
              disposition: params[:download] || !viewable ? "attachment" : "inline"
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
