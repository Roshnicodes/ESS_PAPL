require "test_helper"

# Formulas copied from the live ESS claim form (tour_ta_da.php)
class ClaimCalculationTest < ActiveSupport::TestCase
  setup do
    @emp = user("1025"); @am = user("AM001")
    @tour = @emp.tours.create!(send_now: true, from_date: Date.current - 6, to_date: Date.current - 4, general_description: "Visit",
      tour_visits_attributes: [ { visit_date: Date.current - 6, place: "Jhabua", planned_activity: "SHG" } ])
    @tour.approve!(by: @am)
    @claim = with_tasks(TourClaim.build_for(@tour))
  end

  test "NA mode: no places, ticket, km or amount needed – the line counts ₹0" do
    na = mode("NA")
    @claim.claim_city_travels.build(travel_date: @tour.from_date, travel_mode: na, amount: 300, bill_ticket_no: "X1")
    @claim.claim_local_travels.build(travel_date: @tour.from_date, travel_mode: na, meter_from: 10, meter_to: 50, amount: 99)
    @claim.save!
    city = @claim.claim_city_travels.last
    local = @claim.claim_local_travels.last
    assert_equal [ 0, 0 ], [ city.amount.to_i, city.total_amount.to_i ]
    assert_equal [ 0, 0, nil ], [ local.amount.to_i, local.kilometers.to_i, local.rate_per_km ]
    assert_equal 0, @claim.reload.grand_total.to_i
  end

  test "two wheeler: km from meters x 4.25, public transport: typed km and total" do
    @claim.claim_local_travels.build(travel_date: @tour.from_date, place_from: "HO", place_to: "Bank", travel_mode: mode("Two Wheeler"), meter_from: 1200, meter_to: 1265)
    @claim.claim_local_travels.build(travel_date: @tour.from_date, place_from: "HO", place_to: "PAPL", travel_mode: mode("Public Transport"), meter_from: 5, meter_to: 9, kilometers: 12.16, amount: 192.66, purpose: "Bus ticket 4471")
    @claim.save!
    two, pub = @claim.claim_local_travels.order(:id)
    assert_equal 65, two.kilometers
    assert_equal 4.25, two.rate_per_km
    assert_equal 276.25, two.total_amount
    assert_nil pub.meter_from
    assert_equal 12.16, pub.kilometers
    assert_equal 192.66, pub.total_amount
    assert_equal 468.91, @claim.local_travel_total
  end

  test "public transport line needs its bill or ticket reference" do
    line = @claim.claim_local_travels.build(travel_date: @tour.from_date, place_from: "HO", place_to: "PAPL",
      travel_mode: mode("Public Transport"), kilometers: 12, amount: 190)
    assert_not line.valid?
    assert_includes line.errors.full_messages.join, "ticket ref is required for Public Transport"

    line.purpose = "Bus ticket 4471"
    assert line.valid?, line.errors.full_messages.join(", ")
  end

  test "own vehicle line does not need a ticket reference" do
    line = @claim.claim_local_travels.build(travel_date: @tour.from_date, place_from: "HO", place_to: "Bank",
      travel_mode: mode("Two Wheeler"), meter_from: 1200, meter_to: 1265)
    assert line.valid?, line.errors.full_messages.join(", ")
  end

  test "lodging: No of days as typed, Amount = days × rate – a typed amount is ignored" do
    l = @claim.claim_lodgings.build(lodging_date: @tour.from_date, city: City.find_by!(name: "Jhabua"),
      from_date: @tour.from_date.to_time + 12.hours, to_date: @tour.to_date.to_time + 20.hours, rate: 900, no_of_days: 2, amount: 1_750)
    @claim.save!
    assert_equal 2, l.no_of_days                    # not 2.5 from the clock
    assert_equal 1_800, l.amount                    # 2 × 900, not the typed 1,750
    assert_equal 1_800, l.total_amount
  end

  test "lodging needs days and rate from the employee" do
    city = City.find_by!(name: "Jhabua")
    l = @claim.claim_lodgings.build(lodging_date: @tour.from_date, city: city,
      from_date: @tour.from_date.to_time + 10.hours, to_date: @tour.from_date.to_time + 20.hours)
    assert_not l.valid?
    assert l.errors[:no_of_days].any?
    assert l.errors[:rate].any?
    l.assign_attributes(no_of_days: 1.5, rate: 800)
    assert l.valid?, l.errors.full_messages.to_sentence
    @claim.save!
    assert_equal 1_200, l.amount
  end

  test "lodging amount = No of days × rate even if something else is sent" do
    l = @claim.claim_lodgings.build(lodging_date: @tour.from_date, place_name: "Aligarh",
      from_date: @tour.from_date.to_time + 12.hours, to_date: @tour.to_date.to_time + 12.hours, no_of_days: 2, rate: 500, amount: 99)
    assert l.valid?, l.errors.full_messages.to_sentence
    @claim.save!
    assert_equal [ 1_000, 1_000 ], [ l.amount, l.total_amount ]
  end

  test "a reviewer saving deductions keeps the employee's lodging amount" do
    l = @claim.claim_lodgings.build(lodging_date: @tour.from_date, place_name: "Guest house",
      from_date: @tour.from_date.to_time + 10.hours, to_date: @tour.from_date.to_time + 20.hours, no_of_days: 1, rate: 800)
    @claim.save!
    @claim.update_columns(status: "submitted", submitted_at: Time.current, l1_approver_id: @am.id)
    l.reload.update!(deduction_amount: 100, deduction_remark: "Over limit")
    assert_equal 800, l.amount
    assert_equal 700, l.total_amount
  end

  test "DA = days x city DA rate x applicable %" do
    da = @claim.claim_daily_allowances.build(departure_city: "Bhopal", departure_at: @tour.from_date.to_time + 7.hours,
      city: City.find_by!(name: "Indore"), arrival_at: @tour.to_date.to_time + 20.hours, no_of_days: 3, applicable_percent: 50)
    @claim.save!
    assert_equal 600, da.da_rate
    assert_equal 3, da.no_of_days                   # 07:00 day 1 → 20:00 day 3 = 2 days 13 h → 2 + 1 (above 10 h)
    assert_equal 900, da.amount
  end

  test "brief travel detail starts with one report row for every tour day" do
    reports = @claim.claim_visit_reports

    assert_equal @tour.days, reports.size
    assert_equal (@tour.from_date..@tour.to_date).to_a, reports.map(&:visit_date)
    assert_equal ["Jhabua"] * @tour.days, reports.map(&:place_visited)
    assert_equal (@tour.from_date..@tour.to_date).to_a, reports.map(&:planned_date)
  end

  test "grand total, advance and balance" do
    @claim.advance_amount = 500
    @claim.claim_city_travels.build(travel_date: @tour.from_date, departure_city: "Bhopal", arrival_city: "Jhabua", travel_mode: mode("Bus"), amount: 620)
    @claim.claim_incidentals.build(expense_date: @tour.from_date, particular: "Tea", amount: 80)
    @claim.save!
    assert_equal 700, @claim.grand_total
    assert_equal 200, @claim.balance_amount
  end

  test "helmet declaration only needed when a two wheeler is used" do
    @claim.claim_incidentals.build(expense_date: @tour.from_date, particular: "Tea", amount: 80)
    @claim.save!
    @claim.submit!(by: @emp)                       # no two wheeler -> no helmet needed
    assert @claim.submitted?

    tour2 = @emp.tours.create!(send_now: true, from_date: Date.current - 12, to_date: Date.current - 11,
      tour_visits_attributes: [ { visit_date: Date.current - 12, place: "Sehore", planned_activity: "Mtg" } ])
    tour2.approve!(by: @am)
    c2 = with_tasks(TourClaim.build_for(tour2))
    c2.claim_local_travels.build(travel_date: tour2.from_date, place_from: "A", place_to: "B", travel_mode: mode("Two Wheeler"), meter_from: 1, meter_to: 11)
    c2.save!
    assert_raises(ActiveRecord::RecordInvalid) { c2.submit!(by: @emp) }
    c2.reload.update!(helmet_declaration: true)
    c2.submit!(by: @emp)
    assert c2.submitted?
  end

  test "project / funder names are stripped from descriptions" do
    [ "Tata Trust", "NABARD MP" ].each { |n| Project.find_or_create_by!(name: n) }
    @claim.general_description = "Meeting for Tata Trust and NABARD MP villages by PAPL team at Kasaravad"
    @claim.save!
    assert_equal "Meeting for and villages by team at Kasaravad", @claim.general_description
    assert @claim.blocked_words_removed?
  end

  test "lodging days and amount as typed; DA keeps the city master rate" do
    city = City.find_by!(name: "Jhabua")
    l = @claim.claim_lodgings.build(lodging_date: @tour.from_date, city: city, rate: 700, no_of_days: 1.5, amount: 1_050,
      from_date: @tour.from_date.to_time + 10.hours, to_date: @tour.from_date.to_time + 1.day + 18.hours)
    d = @claim.claim_daily_allowances.build(departure_city: "Bhopal", city: city, da_rate: 1,
      departure_at: @tour.from_date.to_time + 10.hours, arrival_at: @tour.from_date.to_time + 1.day + 18.hours, applicable_percent: 100)
    @claim.save!
    assert_equal 700, l.rate
    assert_equal 1.5, l.no_of_days                  # 1 day 8 h
    assert_equal 1050, l.amount
    assert_equal city.da_rate, d.da_rate             # DA rate from the master, typed 1 ignored
  end
end
