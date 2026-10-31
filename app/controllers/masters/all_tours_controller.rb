# Admin: every tour of every employee – view, edit, delete.
class Masters::AllToursController < ApplicationController
  before_action { raise CanCan::AccessDenied, "Only admin" unless current_user.admin? }

  def index
    @tours = Tour.includes(:user, :approver, :l2_approver, :tour_claim).order(created_at: :desc)
    if params[:q].present?
      q = "%#{Tour.sanitize_sql_like(params[:q].strip)}%"
      @tours = @tours.joins(:user).where("users.name ILIKE :q OR users.emp_code ILIKE :q", q: q)
    end
    @tours = @tours.where(status: params[:status]) if params[:status].present?
    @tours = @tours.where(tour_type: params[:type]) if params[:type].present?
    @tours = @tours.page(params[:page]).per(30)
  end
end
