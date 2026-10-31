# PD HR: Local mileage cutoff day – for all employees or employee-wise.
class Masters::ClaimCutoffRulesController < ApplicationController
  load_and_authorize_resource

  def index
    @global    = ClaimCutoffRule.global
    @overrides = ClaimCutoffRule.overrides.includes(:user, :updated_by).joins(:user).order("users.name")
    @logs      = ActivityLog.where(trackable_type: "ClaimCutoffRule").includes(:actor, :trackable).recent.limit(20)
  end

  def new
    @claim_cutoff_rule.cutoff_day = ClaimCutoffRule.global&.cutoff_day || ClaimCutoffRule::DEFAULT_DAY
  end

  def edit; end

  def create
    @claim_cutoff_rule.updated_by = current_user
    if @claim_cutoff_rule.save
      redirect_to masters_claim_cutoff_rules_path, notice: "Cutoff rule saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @claim_cutoff_rule.update(claim_cutoff_rule_params.merge(updated_by: current_user))
      redirect_to masters_claim_cutoff_rules_path, notice: "Cutoff rule updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @claim_cutoff_rule.global?
      redirect_to masters_claim_cutoff_rules_path, alert: "The all-employee rule cannot be removed, only changed."
    else
      @claim_cutoff_rule.log_activity!(:cutoff_removed, details: { scope: @claim_cutoff_rule.user.emp_code, day: @claim_cutoff_rule.cutoff_day })
      @claim_cutoff_rule.destroy!
      redirect_to masters_claim_cutoff_rules_path, notice: "Employee override removed; all-employee rule applies."
    end
  end

  private

  def claim_cutoff_rule_params
    params.require(:claim_cutoff_rule).permit(:user_id, :cutoff_day, :remark)
  end
end
