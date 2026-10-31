# Employee's own bank accounts + passbook copy (chosen on every claim, shown to Finance).
class Account::BankAccountsController < ApplicationController
  before_action :set_account, except: %i[index new create]

  def index
    @accounts = current_user.bank_accounts.with_attached_passbook.ordered
    @logs = ActivityLog.where(trackable_type: "BankAccount", trackable_id: BankAccount.unscoped.where(user_id: current_user.id).select(:id))
                       .includes(:actor, :trackable).order(created_at: :desc).limit(30)
  end

  def new
    @account = current_user.bank_accounts.new(account_holder_name: current_user.name)
  end

  def create
    @account = current_user.bank_accounts.new(account_params)
    if @account.save
      @account.log_activity!(:bank_added, details: { account: @account.masked_number })
      redirect_to account_bank_accounts_path, notice: "Bank account added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @account
  end

  def update
    authorize! :update, @account
    @account.assign_attributes(account_params)
    changed = @account.changed - %w[updated_at]
    changed << "passbook" if account_params[:passbook].present?
    if @account.save
      @account.log_activity!(:bank_updated, details: { account: @account.masked_number, fields: changed })
      redirect_to account_bank_accounts_path, notice: "Bank account updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle
    authorize! :toggle, @account
    @account.toggle_active!
    @account.log_activity!(@account.active? ? :bank_activated : :bank_deactivated, details: { account: @account.masked_number })
    redirect_to account_bank_accounts_path, notice: "#{@account.label} #{@account.active? ? 'activated' : 'deactivated'}."
  end

  def make_primary
    authorize! :make_primary, @account
    return redirect_to(account_bank_accounts_path, alert: "Activate the account first.") unless @account.active?
    @account.update!(primary: true)
    @account.log_activity!(:bank_primary, details: { account: @account.masked_number })
    redirect_to account_bank_accounts_path, notice: "#{@account.bank_name} is now your primary account."
  end

  # Served through the app (never a public link) so only the owner / that claim's Finance can open it.
  def passbook
    authorize! :read, @account
    return head(:not_found) unless @account.passbook.attached?
    blob = @account.passbook.blob
    send_data blob.download, filename: blob.filename.to_s, type: blob.content_type, disposition: "inline"
  end

  private

  def set_account
    @account = BankAccount.find(params[:id])
  end

  def account_params
    params.require(:bank_account).permit(:account_holder_name, :bank_name, :branch_name, :account_number,
                                         :account_number_confirmation, :ifsc_code, :account_type, :passbook)
  end
end
