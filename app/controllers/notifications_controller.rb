class NotificationsController < ApplicationController
  def index
    @notifications = current_user.notifications.includes(:actor).page(params[:page]).per(30)
  end

  # open = mark read + go to the page
  def show
    n = current_user.notifications.find(params[:id])
    n.mark_read!
    redirect_to n.url
  end

  # Tour History: opening a tour's history marks its (and its claim's) notifications as read
  def read_for_tour
    tour = current_user.tours.find(params[:tour_id])
    scope = current_user.notifications.unread
    ids = scope.where(notifiable: tour).or(scope.where(notifiable_type: "TourClaim", notifiable_id: TourClaim.where(tour_id: tour.id).select(:id))).pluck(:id)
    Notification.where(id: ids).update_all(read_at: Time.current)
    head :no_content
  end

  def mark_all_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    redirect_back fallback_location: notifications_path, notice: "All notifications marked as read."
  end
end
