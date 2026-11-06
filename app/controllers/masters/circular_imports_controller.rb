# Admin: bring the OLD IOMs / Circulars into ESS in one go – the Excel sheet (optional) + a whole folder of files.
# The page's script sends a big folder in batches; every batch is answered with JSON and the last one may
# send the email notification for the IOMs created (off by default – these are old IOMs).
class Masters::CircularImportsController < ApplicationController
  before_action -> { authorize!(:manage, Circular) }

  def new; end

  def template
    send_data CircularImport.template_xlsx, filename: "old_ioms_template.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def create
    sheet = params[:sheet].presence
    if sheet && !File.extname(sheet.original_filename).downcase.in?(%w[.xlsx .xls .csv])
      return render json: { error: "The sheet must be .xlsx or .csv" }, status: :unprocessable_entity
    end
    result = CircularImport.new(by: current_user, files: Array(params[:files]), sheet_path: sheet&.tempfile&.path,
                                sheet_name: sheet&.original_filename, default_type: params[:default_type],
                                default_date: parse_date(params[:default_date])).call
    notified = notify(Array(params[:notify_ids]) + result.created_ids) if ActiveModel::Type::Boolean.new.cast(params[:final]) && notify?
    render json: result.to_h.merge(notified: notified.to_i)
  rescue ArgumentError, Zip::Error => e
    render json: { error: "Could not read the sheet: #{e.message}" }, status: :unprocessable_entity
  end

  private

  def notify? = ActiveModel::Type::Boolean.new.cast(params[:send_notification])

  def notify(ids)
    circulars = Circular.live.where(id: ids.map(&:to_i).uniq)
    circulars.each { |c| CircularNotifyJob.perform_later(c.id, current_user.id) }
    circulars.size
  end

  def parse_date(value)
    Date.parse(value.to_s) if value.present?
  rescue Date::Error
    nil
  end
end
