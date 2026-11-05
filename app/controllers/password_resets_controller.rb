# "Forgot password?" on the login page – no login needed.
#
#   1. The employee types the Employee Code. If that employee is active and has an email in the Employee List,
#      a one-time link is mailed through krai (EssMailRelay – the same route as every ESS notification mail).
#      The answer on screen is the same for every code, so nobody can find out which codes exist.
#      The mail is sent straight away (not queued) and the new token is saved only after krai confirms it,
#      so a mail outage never invalidates a link the employee already has.
#   2. The link (valid for VALID_FOR) opens a form for the new password. Using it once makes it invalid.
# Employees without an email are told to ask HR / Admin, who can set a password in Masters → Employee List.
class PasswordResetsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action { redirect_to authenticated_root_path if user_signed_in? }

  VALID_FOR = 2.hours
  RESEND_AFTER = 2.minutes

  def new; end

  def create
    user = User.active.find_by("lower(emp_code) = ?", params[:emp_code].to_s.strip.downcase)
    if user&.email.present? && !(user.reset_password_sent_at && user.reset_password_sent_at > RESEND_AFTER.ago)
      send_link(user)
    end
    redirect_to new_session_path(:user), notice: "If this Employee Code has an email in the Employee List, a link to set a new password " \
                                                 "has been sent to it (valid for 2 hours). No email? Ask HR / Admin to reset your password."
  end

  def edit
    @user = user_for_token or return redirect_to(new_password_reset_path, alert: "This link has expired or was already used. Ask for a new one.")
  end

  def update
    @user = user_for_token or return redirect_to(new_password_reset_path, alert: "This link has expired or was already used. Ask for a new one.")
    @user.password = params[:password].to_s
    @user.password_confirmation = params[:password_confirmation].to_s
    if params[:password].present? && @user.save
      @user.update_columns(reset_password_token: nil, reset_password_sent_at: nil)
      @user.log_activity!(:password_reset, actor: @user) if @user.respond_to?(:log_activity!)
      redirect_to new_session_path(:user), notice: "Password changed. Log in with your Employee Code and the new password."
    else
      @user.errors.add(:password, "can't be blank") if params[:password].blank?
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_for_token
    digest = Devise.token_generator.digest(User, :reset_password_token, params[:token].to_s)
    user = User.active.find_by(reset_password_token: digest) if params[:token].present?
    user if user&.reset_password_sent_at && user.reset_password_sent_at > VALID_FOR.ago
  end

  # Token pair made here (not saved yet): if krai fails, the employee's earlier link keeps working.
  def send_link(user)
    raw, digest = Devise.token_generator.generate(User, :reset_password_token)
    sent_at = Time.current
    # saved paths never carry the /papl sub-path – app_url (https://hr.asaindia.org/papl) already has it
    link = "#{EssMailRelay.app_url}#{Rails.application.routes.url_helpers.edit_password_reset_path(token: raw)}"
    mail = {
      "to_email" => user.email.strip, "to_name" => user.name.to_s, "subject" => "PAPL ESS: Set a new password",
      "message" => "A new password was asked for Employee Code #{user.emp_code}. Open the link within 2 hours to set it. " \
                   "If you did not ask for this, ignore this mail – your password stays the same.",
      "link" => link, "employee_name" => user.name.to_s, "employee_code" => user.emp_code.to_s,
      "quarter" => "", "month" => "", "reviewer_role" => "", "reviewer_name" => "",
      # krai accepts `pending` for a mail that needs the recipient to act; `information` is refused as an invalid action
      "action" => "pending", "remarks" => "", "mail_type" => "password_reset"
    }
    EssMailRelay.deliver!(mail, relay_url: EssMailRelay.password_reset_url)
    user.update_columns(reset_password_token: digest, reset_password_sent_at: sent_at)
    true
  rescue StandardError => e
    Rails.logger.error("Password reset mail failed for #{user.emp_code}: #{e.class} #{e.message}")
    false
  end
end
