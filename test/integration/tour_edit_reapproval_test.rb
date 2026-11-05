require "test_helper"

# Employee may edit a tour plan until a claim is made: while it is pending, and also after it is approved.
# Saving a changed pending / approved plan sends it to L1 again; an unchanged save keeps it as it was.
class TourEditReapprovalTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @l1 = user("AM001")
    @tour = @emp.tours.create!(from_date: Date.current + 3, to_date: Date.current + 4, send_now: true, general_description: "SHG visit",
      tour_visits_attributes: [ { visit_date: Date.current + 3, place: "Jhabua", planned_activity: "Visit" } ])
    assert @tour.submitted?
  end

  test "pending tour: Edit is offered and saving a change sends it to L1 again" do
    sign_in @emp
    get tours_path
    assert_match edit_tour_path(@tour), response.body
    get edit_tour_path(@tour)
    assert_response :success
    assert_match "Save &amp; Send Again", response.body

    patch tour_path(@tour), params: { commit_action: "send", tour: { general_description: "SHG visit + bank meeting" } }
    assert_redirected_to tour_path(@tour)
    @tour.reload
    assert @tour.submitted?
    assert_equal "SHG visit + bank meeting", @tour.general_description
    assert_includes Tour.pending_for(@l1), @tour
  end

  test "approved tour edited by the employee goes back for approval; no change keeps it approved" do
    @tour.approve!(by: @l1, remark: "ok")
    assert @tour.reload.approved?
    sign_in @emp

    patch tour_path(@tour), params: { commit_action: "send", tour: { general_description: @tour.general_description } }
    assert @tour.reload.approved?                                      # nothing changed – stays approved

    get edit_tour_path(@tour)
    assert_response :success
    assert_match "already approved", response.body
    patch tour_path(@tour), params: { commit_action: "send", tour: { general_description: "Plan changed" } }
    @tour.reload
    assert @tour.submitted?, @tour.status                              # back to L1
    assert_nil @tour.approved_at
    assert_includes Tour.pending_for(@l1), @tour
  end

  test "once the claim is made the plan cannot be edited" do
    @tour.approve!(by: @l1, remark: "ok")
    @tour.update_columns(from_date: Date.current - 4, to_date: Date.current - 3)
    @tour.tour_visits.update_all(visit_date: Date.current - 4)
    with_tasks(TourClaim.build_for(@tour.reload)).save!
    sign_in @emp
    get edit_tour_path(@tour)
    assert_response :redirect
    assert_not @tour.reload.maker_editable?
  end
end
