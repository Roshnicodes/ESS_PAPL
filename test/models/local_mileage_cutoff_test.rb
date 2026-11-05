require "test_helper"

# A Local Mileage claim for month M may be filled and sent only till the cutoff day of M+1.
class LocalMileageCutoffTest < ActiveSupport::TestCase
  setup { @emp = user("1025") }

  def period(today) = LocalMileagePeriod.new(@emp, today: today)

  test "deadline is the cutoff day of the next month" do
    ClaimCutoffRule.find_or_initialize_by(user_id: nil).update!(cutoff_day: 5, updated_by: user("ADMIN"))
    p = period(Date.new(2026, 11, 3))
    assert_equal Date.new(2026, 11, 5), p.deadline_for(Date.new(2026, 10, 1))
    assert_equal Date.new(2026, 12, 5), p.deadline_for(Date.new(2026, 11, 1))
  end

  test "October stays open till the cutoff day and closes the day after" do
    ClaimCutoffRule.find_or_initialize_by(user_id: nil).update!(cutoff_day: 5, updated_by: user("ADMIN"))
    oct = Date.new(2026, 10, 1)
    refute period(Date.new(2026, 11, 5)).closed?(oct), "5-Nov is the last day – still open"
    assert period(Date.new(2026, 11, 6)).closed?(oct), "6-Nov – October is closed"
    assert period(Date.new(2026, 12, 1)).closed?(oct)
  end

  test "a cutoff day beyond the month length is clamped" do
    ClaimCutoffRule.find_or_initialize_by(user_id: nil).update!(cutoff_day: 28, updated_by: user("ADMIN"))
    # Jan-2027 claim -> deadline 28-Feb-2027 (February has 28 days)
    assert_equal Date.new(2027, 2, 28), period(Date.new(2027, 2, 1)).deadline_for(Date.new(2027, 1, 1))
  end

  test "a per-employee override wins over the all-employee rule" do
    ClaimCutoffRule.find_or_initialize_by(user_id: nil).update!(cutoff_day: 5, updated_by: user("ADMIN"))
    ClaimCutoffRule.create!(user: @emp, cutoff_day: 10, updated_by: user("ADMIN"))
    assert_equal Date.new(2026, 11, 10), period(Date.new(2026, 11, 1)).deadline_for(Date.new(2026, 10, 1))
  end

  test "a saved draft of a closed month cannot be sent" do
    ClaimCutoffRule.find_or_initialize_by(user_id: nil).update!(cutoff_day: 5, updated_by: user("ADMIN"))
    tour = travel_to(Date.new(2026, 11, 2)) { local_tour_with_draft }
    assert_equal Date.new(2026, 10, 1), tour.claim_month

    travel_to Date.new(2026, 11, 6) do
      claim = tour.tour_claim.reload
      assert claim.local_month_closed?
      claim.submitting = true
      refute claim.valid?
      assert_match(/Oct-2026 can no longer be filled or sent/, claim.errors.full_messages.to_sentence)
    end
  end

  test "the same draft can still be sent on the cutoff day itself" do
    ClaimCutoffRule.find_or_initialize_by(user_id: nil).update!(cutoff_day: 5, updated_by: user("ADMIN"))
    tour = travel_to(Date.new(2026, 11, 2)) { local_tour_with_draft }

    travel_to Date.new(2026, 11, 5) do
      claim = tour.tour_claim.reload
      refute claim.local_month_closed?
      claim.submit!(by: @emp)
      assert_equal "submitted", claim.reload.status
    end
  end

  private

  def local_tour_with_draft
    tour = @emp.tours.create!(tour_type: "local", general_description: "local travel milage claim")
    claim = TourClaim.build_for(tour)
    claim.claim_local_travels.build(travel_date: Date.new(2026, 10, 12), place_from: "Office", place_to: "Field",
                                    travel_mode: mode("Public Transport"), kilometers: 10, amount: 100, purpose: "Field visit")
    claim.bank_account = @emp.bank_accounts.first
    claim.save!
    tour
  end
end
