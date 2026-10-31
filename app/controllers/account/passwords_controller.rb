# Any logged-in employee can change their own password (current password required).
class Account::PasswordsController < ApplicationController
  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update_with_password(password_params)
      @user.log_activity!(:password_changed)
      bypass_sign_in(@user)
      redirect_to authenticated_root_path, notice: "Password changed successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
