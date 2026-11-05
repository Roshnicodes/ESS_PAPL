# Admin: IOM / Circular – write it, attach the files, choose who is told, activate / deactivate.
class Masters::CircularsController < ApplicationController
  # Every employee may READ a circular, so reading rights alone must not open these
  # screens – writing one is an admin job.
  before_action -> { authorize!(:manage, Circular) }
  load_and_authorize_resource

  def index
    @circulars = Circular.includes(:created_by, :circular_recipients).with_attached_attachments.newest_first.page(params[:page]).per(20)
  end

  def new
    @circular.topic_type ||= "circular"
  end

  def edit; end

  def create
    @circular.created_by = current_user
    apply_recipients
    attach_new_files
    if @circular.save
      @circular.log_activity!(:circular_created, details: log_details)
      notify_now
      redirect_to masters_circulars_path, notice: "#{@circular.type_label} saved.#{notice_tail}"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @circular.assign_attributes(circular_params)
    apply_recipients
    attach_new_files
    if @circular.save
      purge_marked_attachments
      @circular.log_activity!(:circular_updated, details: log_details)
      notify_now
      redirect_to masters_circulars_path, notice: "#{@circular.type_label} updated.#{notice_tail}"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle
    @circular.update!(active: !@circular.active?)
    @circular.log_activity!(@circular.active? ? :circular_activated : :circular_deactivated)
    redirect_to masters_circulars_path,
      notice: "#{@circular.type_label} “#{@circular.topic}” #{@circular.active? ? 'activated – employees can see it' : 'deactivated – hidden from employees'}."
  end

  # Send the mail / bell again (e.g. after adding an attachment, or to employees added later)
  def notify
    return redirect_to(masters_circulars_path, alert: "Activate it before sending the notification.") unless @circular.active?
    CircularNotifyJob.perform_later(@circular.id, current_user.id)
    redirect_to masters_circulars_path, notice: "Notification is being sent to #{@circular.audience_label.downcase}."
  end

  private

  # "All employees" keeps no recipient rows; "Selected" replaces the list with the ticked people.
  def apply_recipients
    return @circular.circular_recipients.each(&:mark_for_destruction) if @circular.to_all?
    wanted = User.active.where(id: Array(params[:recipient_ids]).map(&:to_i)).pluck(:id)
    existing = @circular.circular_recipients.index_by(&:user_id)
    (existing.keys - wanted).each { |uid| existing[uid].mark_for_destruction }
    (wanted - existing.keys).each { |uid| @circular.circular_recipients.build(user_id: uid) }
  end

  # Files are ATTACHED, never assigned. Assigning to a has_many_attached replaces the whole
  # set, so an edit that adds no new file would silently delete the ones already there.
  def attach_new_files
    files = Array(params.dig(:circular, :attachments)).reject(&:blank?)
    @circular.attachments.attach(files) if files.any?
  end

  def purge_marked_attachments
    ids = Array(params[:remove_attachment_ids]).map(&:to_i)
    @circular.attachments.select { |a| ids.include?(a.id) }.each(&:purge_later) if ids.any?
  end

  def notify_now
    return unless notify_requested? && @circular.active?
    CircularNotifyJob.perform_later(@circular.id, current_user.id)
  end

  def notify_requested? = ActiveModel::Type::Boolean.new.cast(params[:send_notification])

  def notice_tail
    return " It is inactive – nobody is notified until you activate it." unless @circular.active?
    notify_requested? ? " Email notification is going to #{@circular.audience_label.downcase}." : " No notification sent (tick “Send email notification” to inform employees)."
  end

  def log_details
    { topic: @circular.topic, type: @circular.topic_type, audience: @circular.audience,
      recipients: @circular.to_all? ? "all" : @circular.circular_recipients.reject(&:marked_for_destruction?).size,
      attachments: @circular.attachments.size }
  end

  def circular_params
    params.require(:circular).permit(:topic_type, :topic, :description, :audience, :active)
  end
end
