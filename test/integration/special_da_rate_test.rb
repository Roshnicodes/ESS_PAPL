require "test_helper"

# Special DA rate by position: some employees get another DA rate; everyone else keeps the city rate.
class SpecialDaRateTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @other = user("AM001")
    @emp.update_columns(level: "L - 5", designation: "Project Associate")
    @other.update_columns(level: "L - 3", designation: "Area Manager")
    @bhopal = City.find_by!(name: "Bhopal"); @jhabua = City.find_by!(name: "Jhabua")
    @admin = user("ADMIN")
  end

  def rule(type, value, rate, city: nil) = DaRateRule.create!(match_type: type, match_value: value, da_rate: rate, city: city, created_by: @admin)

  test "no rule → city rate; employee beats designation beats level; a city rule beats an all-cities rule" do
    assert_nil DaRateRule.rate_for(@emp, @bhopal)
    rule("level", "L-5", 400)                                   # written without spaces – still the same level
    assert_equal 400, DaRateRule.rate_for(@emp, @bhopal)
    assert_nil DaRateRule.rate_for(@other, @bhopal)              # other level keeps the city rate
    rule("level", "L - 5", 450, city: @bhopal)
    assert_equal 450, DaRateRule.rate_for(@emp, @bhopal)
    assert_equal 400, DaRateRule.rate_for(@emp, @jhabua)
    rule("designation", "project associate", 500)
    assert_equal 500, DaRateRule.rate_for(@emp, @bhopal)
    rule("employee", "1025", 700)
    assert_equal 700, DaRateRule.rate_for(@emp, @bhopal)
    DaRateRule.find_by(match_type: "employee").update!(active: false)
    assert_equal 500, DaRateRule.rate_for(@emp, @bhopal)
  end

  test "a rule must name a real level / designation / employee and cannot be entered twice" do
    bad = DaRateRule.new(match_type: "level", match_value: "L - 99", da_rate: 100)
    assert_not bad.valid?
    rule("level", "L - 5", 400)
    assert_not DaRateRule.new(match_type: "level", match_value: "l-5", da_rate: 300).valid?
  end

  test "the claim's DA uses the employee's special rate; the city rate stays for others" do
    rule("level", "L - 5", 400)
    tour = @emp.tours.create!(send_now: true, from_date: Date.current - 6, to_date: Date.current - 5,
      tour_visits_attributes: [ { visit_date: Date.current - 6, place: "Bhopal", planned_activity: "Mtg" } ])
    tour.approve!(by: @emp.reporting_manager, remark: "ok")
    claim = TourClaim.build_for(tour)
    da = claim.claim_daily_allowances.build(departure_city: "Office", city: @bhopal, applicable_percent: 100,
      departure_at: (Date.current - 6).to_time + 8.hours, arrival_at: (Date.current - 5).to_time + 20.hours)
    claim.save!
    assert_equal 400, da.reload.da_rate
    assert_equal 400 * da.no_of_days, da.amount

    sign_in @emp
    get edit_tour_claim_path(tour)
    assert_match %(data-rate="400.0" value="#{@bhopal.id}"), response.body          # form picks the special rate too
  end

  test "PD HR / admin manage special DA rates from Masters" do
    sign_in @admin
    get masters_da_rate_rules_path
    assert_response :success
    post masters_da_rate_rules_path, params: { da_rate_rule: { match_type: "designation", match_value: "Area Manager", city_id: "", da_rate: 650, active: "1" } }
    assert_redirected_to masters_da_rate_rules_path
    r = DaRateRule.last
    assert_equal [ "designation", "Area Manager", nil, 650 ], [ r.match_type, r.match_value, r.city_id, r.da_rate.to_i ]
    patch masters_da_rate_rule_path(r), params: { da_rate_rule: { da_rate: 700 } }
    assert_equal 700, r.reload.da_rate.to_i
    delete masters_da_rate_rule_path(r)
    assert_not DaRateRule.exists?(r.id)

    sign_in @emp
    get masters_da_rate_rules_path
    assert_redirected_to root_path
  end
end
