require "test_helper"

class ClaimsHelperTest < ActionView::TestCase
  test "a saved row keeps its mode even when the master no longer offers it" do
    old = TravelMode.create!(name: "Old Mode", active: false, position: 98)
    assert_not_includes city_travel_modes, old
    assert_includes modes_with_current(city_travel_modes, old), old
    assert_equal city_travel_modes, modes_with_current(city_travel_modes, nil)
    assert_equal city_travel_modes, modes_with_current(city_travel_modes, city_travel_modes.first)
  end
end
