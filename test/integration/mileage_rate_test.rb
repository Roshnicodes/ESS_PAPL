require "test_helper"

class MileageRateTest < ActionDispatch::IntegrationTest
  setup do
    @two = mode("Two Wheeler")
    MileageRate.where(travel_mode_id: @two.id).delete_all
  end

  def add_rate(rate, on)
    @two.mileage_rates.create!(rate_per_km: rate, effective_from: on, created_by: user("FIN001"))
  end

  test "a rate holds until it is changed – also for trips before the first rate was entered" do
    add_rate(4.25, Date.new(2026, 11, 2))
    add_rate(5.00, Date.new(2026, 12, 1))
    @two.reload
    assert_equal 4.25, @two.rate_on(Date.new(2026, 10, 5)).to_f    # October trip, rate first entered 2 Nov
    assert_equal 4.25, @two.rate_on(Date.new(2026, 11, 20)).to_f
    assert_equal 5.00, @two.rate_on(Date.new(2026, 12, 3)).to_f    # changed from 1 Dec
    assert_equal 4.25, TravelMode.includes(:mileage_rates).find(@two.id).rate_on(Date.new(2026, 10, 5)).to_f   # preloaded path
  end

  test "rate form has no date: the rate counts from today, a second change today replaces today's entry" do
    sign_in user("FIN001")
    get masters_mileage_rates_path
    assert_no_match 'name="mileage_rate[effective_from]"', response.body

    post masters_mileage_rates_path, params: { mileage_rate: { travel_mode_id: @two.id, rate_per_km: 4.25 } }
    post masters_mileage_rates_path, params: { mileage_rate: { travel_mode_id: @two.id, rate_per_km: 4.50 } }
    assert_equal [ [ Date.current, 4.5 ] ], @two.reload.mileage_rates.map { [ _1.effective_from, _1.rate_per_km.to_f ] }

    post masters_mileage_rates_path, params: { mileage_rate: { travel_mode_id: @two.id, rate_per_km: "" } }
    assert_response :unprocessable_entity
    assert_equal [ 4.5 ], @two.reload.mileage_rates.map { _1.rate_per_km.to_f }   # a bad entry never removes today's rate
  end
end
