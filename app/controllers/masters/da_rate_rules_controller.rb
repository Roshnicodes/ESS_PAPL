# Special DA rate by position (PD HR / admin – same people who manage City & DA Rate).
# One save can cover every city or many ticked cities at once; a city that already has a rate for the same
# Level / Designation / Employee gets the new rate instead of a second rule.
class Masters::DaRateRulesController < ApplicationController
  before_action { authorize! :manage, City }
  before_action :set_rule, only: %i[edit update destroy]

  def index
    @rule = DaRateRule.new(match_type: "level", active: true)
    @scope = "all"
    load_page
  end

  def create
    @rule = DaRateRule.new(rule_params.merge(created_by: current_user))
    @scope = params[:city_scope] == "some" ? "some" : "all"
    @city_ids = Array(params[:city_ids]).map(&:to_i).uniq & City.active.pluck(:id)
    if @scope == "some" && @city_ids.empty?
      @rule.errors.add(:base, "Tick at least one city – or choose “All cities”")
      return render_index_again
    end

    added = updated = 0
    DaRateRule.transaction do
      (@scope == "all" ? [ nil ] : @city_ids).each do |city_id|
        rule = DaRateRule.find_same(@rule.match_type, @rule.match_value, city_id) ||
               DaRateRule.new(match_type: @rule.match_type, match_value: @rule.match_value, city_id: city_id, created_by: current_user)
        rule.new_record? ? added += 1 : updated += 1
        rule.assign_attributes(da_rate: @rule.da_rate, active: @rule.active, remark: @rule.remark)
        unless rule.save
          rule.errors.full_messages.each { |m| @rule.errors.add(:base, m) }
          raise ActiveRecord::Rollback
        end
      end
    end
    return render_index_again if @rule.errors.any?

    where = @scope == "all" ? "all cities" : "#{@city_ids.size} #{'city'.pluralize(@city_ids.size)}"
    parts = [ ("#{added} added" if added.positive?), ("#{updated} updated" if updated.positive?) ].compact.join(", ")
    redirect_to masters_da_rate_rules_path, notice: "#{@rule.applies_to} – ₹#{format("%.2f", @rule.da_rate)}/day in #{where} (#{parts})."
  end

  def edit; end

  def update
    if @rule.update(params.require(:da_rate_rule).permit(:da_rate, :active, :remark, :city_id))
      redirect_to masters_da_rate_rules_path, notice: "Updated – #{@rule.applies_to}, #{@rule.city_label}: ₹#{format("%.2f", @rule.da_rate)}/day."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # one rule, or (?group=1) every city of that Level / Designation / Employee
  def destroy
    rules = params[:group].present? ? DaRateRule.group_of(@rule) : [ @rule ]
    DaRateRule.where(id: rules.map(&:id)).delete_all
    redirect_to masters_da_rate_rules_path, notice: "Removed #{rules.size} special DA #{'rate'.pluralize(rules.size)} for #{@rule.applies_to}. The city rate applies again."
  end

  private

  def set_rule = @rule = DaRateRule.find(params[:id])

  def rule_params = params.require(:da_rate_rule).permit(:match_type, :match_value, :da_rate, :active, :remark)

  def render_index_again
    load_page
    render :index, status: :unprocessable_entity
  end

  def load_page
    @cities = City.active.ordered.to_a
    @choices = DaRateRule.choices
    rules = DaRateRule.includes(:city).ordered.to_a
    @groups = rules.group_by { |r| [ r.match_type, DaRateRule.norm(r.match_type, r.match_value) ] }
                   .map { |(type, key), list| { type: type, value: list.first.match_value, count: @choices.dig(type, key, :count).to_i,
                                                 rules: list.sort_by { |r| [ r.city_id ? 1 : 0, r.city_label ] } } }
                   .sort_by { |g| [ DaRateRule::PRIORITY.index(g[:type]), g[:value].downcase ] }
  end
end
