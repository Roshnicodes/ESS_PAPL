# Special DA rate by position (PD HR / admin – same people who manage City & DA Rate).
class Masters::DaRateRulesController < ApplicationController
  before_action { authorize! :manage, City }
  before_action :set_rule, only: %i[edit update destroy]

  def index
    @rule = DaRateRule.new(match_type: "level", active: true)
    load_list
  end

  def create
    @rule = DaRateRule.new(rule_params.merge(created_by: current_user))
    if @rule.save
      redirect_to masters_da_rate_rules_path, notice: "Special DA rate saved – #{@rule.applies_to}, #{@rule.city_label}: ₹#{@rule.da_rate}/day."
    else
      load_list
      render :index, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @rule.update(rule_params)
      redirect_to masters_da_rate_rules_path, notice: "Special DA rate updated – #{@rule.applies_to}, #{@rule.city_label}."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rule.destroy!
    redirect_to masters_da_rate_rules_path, notice: "Special DA rate removed – #{@rule.applies_to}, #{@rule.city_label}. The city rate applies again."
  end

  private

  def set_rule = @rule = DaRateRule.find(params[:id])

  def rule_params = params.require(:da_rate_rule).permit(:match_type, :match_value, :city_id, :da_rate, :active, :remark)

  def load_list
    @rules = DaRateRule.includes(:city, :created_by).ordered
    if params[:q].present?
      q = params[:q].to_s.strip.downcase
      @rules = @rules.select { |r| [ r.match_value, r.city_label, r.remark ].compact.any? { |v| v.downcase.include?(q) } }
    end
  end
end
