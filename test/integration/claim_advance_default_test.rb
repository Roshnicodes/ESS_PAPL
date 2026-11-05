require "test_helper"

# "Less Advance Taken" left blank must be taken as 0, not refused as "is not a number".
class ClaimAdvanceDefaultTest < ActionDispatch::IntegrationTest
  setup { @emp = user("1025") }

  test "a blank advance saves as zero" do
    tour = local_tour
    claim = TourClaim.new(tour: tour, user: @emp, claim_type: "local", advance_amount: "")
    claim.claim_local_travels.build(travel_date: tour.from_date, place_from: "Office", place_to: "Field",
                                    travel_mode: mode("Public Transport"), kilometers: 8, amount: 80, purpose: "Visit")
    claim.bank_account = @emp.bank_accounts.first
    assert claim.save, claim.errors.full_messages.to_sentence
    assert_equal 0, claim.reload.advance_amount
    assert_equal 80, claim.balance_amount
  end

  test "sending a local mileage claim without typing an advance works" do
    sign_in @emp
    post local_mileage_path, params: { commit_action: "submit", tour_claim: {
      bank_account_id: @emp.bank_accounts.first.id,
      claim_local_travels_attributes: { "0" => { travel_date: LocalMileagePeriod.new(@emp).month.strftime("%Y-%m-%d"), place_from: "Office",
        place_to: "Field", travel_mode_id: mode("Public Transport").id, kilometers: "12", amount: "120", purpose: "SHG meeting" } }
    } }
    assert_redirected_to tours_path(type: "local")
    claim = TourClaim.order(:id).last
    assert_equal "submitted", claim.status
    assert_equal 0, claim.advance_amount
  end

  test "a typed advance is still used" do
    tour = local_tour
    claim = TourClaim.new(tour: tour, user: @emp, claim_type: "local", advance_amount: "50")
    claim.claim_local_travels.build(travel_date: tour.from_date, place_from: "A", place_to: "B",
                                    travel_mode: mode("Public Transport"), kilometers: 8, amount: 80, purpose: "Visit")
    assert claim.save, claim.errors.full_messages.to_sentence
    assert_equal 50, claim.advance_amount
    assert_equal 30, claim.balance_amount
  end

  private

  def local_tour = @emp.tours.create!(tour_type: "local", general_description: "local travel milage claim")
end
