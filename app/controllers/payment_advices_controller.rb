# Payment Advice – PD Finance records the bank UTR against approved claims.
#
#   Pick FY + month (and TA/DA / Local Mileage, or both) → the list shows only claims that
#   are approved and still have no UTR. Tick one, several or all and record a UTR for them
#   in one go, or type a different one on a single row. The same list downloads as an Excel
#   that can be filled in and uploaded back for a bulk update.
class PaymentAdvicesController < ApplicationController
  include ClaimPeriodFilter

  before_action :require_payment_role
  before_action :set_claim_period, only: :index

  TYPES = { "all" => nil, "tour" => "tour", "local" => "local" }.freeze

  def index
    @type  = TYPES.key?(params[:type].to_s) ? params[:type].to_s : "all"
    @scope = params[:scope].to_s == "paid" ? "paid" : "pending"
    @claims = filter_by_period(base_scope)
    @totals = payment_totals(@claims)
    respond_to do |format|
      format.html { @claims = @claims.page(params[:page]).per(50) }
      format.xlsx do
        send_data PaymentAdviceExport.new(@claims, period: period_label).to_xlsx,
                  filename: "payment_advice_#{@scope}_#{period_slug}_#{Date.current}.xlsx",
                  type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      end
      format.csv do
        send_data PaymentAdviceExport.new(@claims, period: period_label).to_csv,
                  filename: "payment_advice_#{@scope}_#{period_slug}_#{Date.current}.csv", type: "text/csv"
      end
    end
  end

  # One UTR applied to every ticked claim (one row, many rows, or Select all).
  def record
    ids = Array(params[:claim_ids]).map(&:to_i).reject(&:zero?)
    utr = params[:utr_no].to_s.strip
    return back_with(alert: "Tick at least one claim first.") if ids.empty?
    return back_with(alert: "Type the UTR number before saving.") if utr.blank?

    claims = TourClaim.approved.payable_by(current_user).where(id: ids).includes(:tour, :user)
    return back_with(alert: "Those claims are no longer approved – refresh the list.") if claims.empty?

    done, failed = [], []
    TourClaim.transaction do
      claims.each do |claim|
        if claim.record_payment!(utr: utr, by: current_user, paid_on: paid_on_param, remark: params[:payment_remark])
          done << claim
        else
          failed << "#{claim.user.emp_code}: #{claim.errors.full_messages.to_sentence}"
        end
      end
      raise ActiveRecord::Rollback if done.empty?
    end

    missing = ids.size - claims.size
    note = "UTR #{utr} recorded on #{done.size} claim#{"s" unless done.size == 1} (#{helpers.inr(done.sum { |c| c.balance_amount.to_d })})."
    note += " #{missing} were already changed by someone else." if missing.positive?
    failed.any? ? back_with(alert: "#{note} Not saved: #{failed.first(3).to_sentence}") : back_with(notice: note)
  end

  # Upload the filled-in sheet (bulk)
  def import
    file = params[:file]
    return back_with(alert: "Choose the filled Excel / CSV file to upload.") if file.blank?
    unless File.extname(file.original_filename).downcase.in?(%w[.xlsx .csv])
      return back_with(alert: "Only .xlsx or .csv files can be uploaded.")
    end

    result = PaymentAdviceImport.new(file.tempfile.path, by: current_user, original_filename: file.original_filename).call
    note = "#{result.recorded} UTR recorded, #{result.corrected} corrected, #{result.unchanged} already the same, #{result.skipped} skipped."
    flash[:import_errors] = result.errors.first(5).map { |e| e.to_s.truncate(120) } if result.errors.any?
    back_with(notice: note)
  rescue ArgumentError, Zip::Error => e
    back_with(alert: "Could not read the file: #{e.message}")
  end

  private

  def base_scope
    scope = TourClaim.includes(:tour, :user, :project, :approved_by, :utr_updated_by, :bank_account).payable_by(current_user)
    scope = scope.where(claim_type: TYPES[@type]) if TYPES[@type]
    (@scope == "paid" ? scope.paid.order(utr_updated_at: :desc) : scope.awaiting_payment.order(:approved_at))
  end

  def payment_totals(scope)
    row = scope.except(:includes, :preload, :eager_load, :order, :limit, :offset)
               .pluck(Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(grand_total), 0)"),
                      Arel.sql("COALESCE(SUM(advance_amount), 0)"), Arel.sql("COALESCE(SUM(balance_amount), 0)")).first
    count, grand, advance, balance = row
    { count: count.to_i, grand: grand.to_d, advance: advance.to_d, balance: balance.to_d }
  end

  def paid_on_param
    text = params[:paid_on].to_s.strip
    return nil if text.blank?
    Date.parse(text)
  rescue Date::Error
    nil
  end

  def back_with(**flash_message)
    redirect_back fallback_location: payment_advices_path, **flash_message
  end

  # Paying is PD Finance's job – the role, admin, or anyone HR named as a Finance
  # approver (those people often carry the plain "employee" role).
  def require_payment_role
    return if current_user.finance_person?
    raise CanCan::AccessDenied, "Payment Advice is for PD Finance only."
  end
end
