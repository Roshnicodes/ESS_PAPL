require "test_helper"

class TourFlowTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025"); @am = user("AM001"); @mis = user("MIS001"); @fin = user("FIN001"); @hr = user("HR001")
  end

  test "all main pages render for every role" do
    [ @emp, @am, @mis, @fin, @hr, user("ADMIN") ].each do |u|
      sign_in u
      approvals = [ approvals_tours_path, approvals_claims_path, approvals_claims_path(type: "local", scope: "approved") ]
      [ authenticated_root_path, new_tour_path, tours_path, new_local_mileage_path, tours_path(type: "local") ].each do |p|
        get p
        assert_response :success, "#{u.emp_code} #{p}"
      end
      approvals.each do |p|
        get p
        if (p == approvals_tours_path ? u.tour_approver? : u.claim_approver?) then assert_response(:success, "#{u.emp_code} #{p}")
        else assert_redirected_to(authenticated_root_path, "#{u.emp_code} #{p}") end
      end
      sign_out u
    end
    sign_in user("ADMIN")
    [ masters_travel_modes_path, new_masters_travel_mode_path, masters_mileage_rates_path, masters_claim_cutoff_rules_path,
      new_masters_claim_cutoff_rule_path(employee: 1), masters_users_path, new_masters_user_path, edit_masters_user_path(@emp),
      masters_finance_codes_path ].each do |p|
      get p
      assert_response :success, p
    end
  end

  test "Approvals menu only for approvers" do
    sign_in @emp
    get authenticated_root_path
    assert_no_match "Pending Tour Approval", response.body
    sign_out @emp
    sign_in @am                                    # L1 of 1025
    get authenticated_root_path
    assert_match "Pending Tour Approval", response.body
  end

  test "employee cannot open masters" do
    sign_in @emp
    get masters_mileage_rates_path
    assert_redirected_to root_path
  end

  test "tour plan -> approve -> claim after to-date -> verify -> recommend -> finance approve" do
    sign_in @emp
    post tours_path(type: "tour"), params: { commit_action: "send", tour: { from_date: Date.current - 6, to_date: Date.current - 4, general_description: "Field",
      tour_visits_attributes: { "0" => { visit_date: Date.current - 6, place: "Jhabua", travel_mode_id: mode("Bus").id, planned_activity: "SHG" } } } }
    tour = Tour.last
    assert_redirected_to tour_path(tour)
    assert tour.submitted?
    get tour_path(tour); assert_response :success
    get new_tour_claim_path(tour); assert_redirected_to tour_path(tour)  # not approved yet
    sign_out @emp

    sign_in @am
    patch approve_approvals_tour_path(tour), params: { remark: "Go ahead" }
    assert tour.reload.approved?
    sign_out @am

    sign_in @emp
    get new_tour_claim_path(tour); assert_response :success
    @emp.update!(l2_manager: @hr)   # claim goes L1 -> L2 -> PD Finance
    post tour_claim_path(tour), params: { commit_action: "submit", tour_claim: { advance_amount: 100, helmet_declaration: "1",
      claim_city_travels_attributes: { "0" => { travel_date: tour.from_date, departure_city: "Bhopal", arrival_city: "Jhabua", travel_mode_id: mode("Bus").id, amount: 450 } },
      claim_local_travels_attributes: { "0" => { travel_date: tour.from_date, place_from: "Jhabua", place_to: "Village", travel_mode_id: mode("Two Wheeler").id, meter_from: 10, meter_to: 30 } },
      claim_visit_reports_attributes: (tour.from_date..tour.to_date).each_with_index.to_h { |day, i| [ i.to_s, { visit_date: day, place_visited: "Jhabua", tasks_accomplished: "SHG meeting", action_points: "Follow up", time_frame: "1 week", remark: "OK" } ] } } }
    claim = tour.reload.tour_claim
    assert_equal 3, claim.claim_visit_reports.count, "day rows are not duplicated"
    assert claim.submitted?, claim.errors.full_messages.inspect
    assert_equal 450 + 20 * 4.25, claim.grand_total.to_f
    assert_equal claim.grand_total - 100, claim.balance_amount
    get tour_claim_path(tour); assert_response :success
    patch cancel_tour_path(tour), params: { cancel_remark: "x" }
    refute tour.reload.cancelled?, "cannot cancel while claim is under review"
    sign_out @emp

    # L1 (reporting manager) – may apply a deduction, then approves -> goes to L2
    sign_in @am
    get approvals_claim_path(claim); assert_response :success
    assert_no_match "Set by PD Finance", response.body
    line = claim.claim_city_travels.first
    patch approvals_claim_path(claim), params: { tour_claim: { claim_city_travels_attributes: { "0" => { id: line.id, deduction_amount: 50, deduction_remark: "No ticket" } } } }
    assert_equal 50, line.reload.deduction_amount
    patch forward_approvals_claim_path(claim), params: { remark: "ok" }
    assert claim.reload.l1_approved?
    sign_out @am

    # L2 (functional manager) -> PD Finance
    sign_in @hr
    patch forward_approvals_claim_path(claim)
    refute claim.reload.finance_pending?, "remark is mandatory"
    patch forward_approvals_claim_path(claim), params: { remark: "fine" }
    assert claim.reload.finance_pending?
    sign_out @hr

    sign_in @fin
    coding = finance_mapping(project_name: "LEAP", line_item_name: "Travel", code_name: "TR-01")
    get approvals_claim_path(claim); assert_response :success
    %w[project_id budget_line_item_id budget_line_item_code_id].each do |field|
      assert_match "name=\"#{field}\"", response.body
    end
    patch approve_approvals_claim_path(claim), params: { remark: "Approved", project_id: coding.project_id,
                                                         budget_line_item_id: coding.budget_line_item_id, budget_line_item_code_id: coding.budget_line_item_code_id }
    claim.reload
    assert claim.approved?
    assert_equal "LEAP", claim.project.name
    patch approve_approvals_claim_path(claim), params: { remark: "again", project_id: coding.project_id,
                                                         budget_line_item_id: coding.budget_line_item_id, budget_line_item_code_id: coding.budget_line_item_code_id }  # second time is not allowed
    assert_equal 1, Project.where("lower(name) = 'leap'").count
    assert_equal %w[claim_created claim_submitted deduction_updated claim_l1_approved claim_l2_approved claim_approved], claim.activity_logs.pluck(:action)
    assert claim.activity_logs.all? { |l| l.created_at.present? }
    get approvals_claims_path(scope: "approved", format: :xlsx)
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    assert response.body.start_with?("PK")
  end

  test "employee cancels approved tour with remark; shows cancelled immediately" do
    tour = @emp.tours.create!(send_now: true, from_date: Date.current + 3, to_date: Date.current + 4,
      tour_visits_attributes: [ { visit_date: Date.current + 3, place: "Indore", planned_activity: "Mtg" } ])
    tour.approve!(by: @am)
    sign_in @emp
    patch cancel_tour_path(tour), params: { cancel_remark: "" }
    refute tour.reload.cancelled?
    patch cancel_tour_path(tour), params: { cancel_remark: "Meeting postponed" }
    assert tour.reload.cancelled?
    assert_equal "approved", tour.status_before_cancel
    get tours_path
    assert_match "Meeting postponed", response.body
  end

  test "claim form opens only after tour to-date" do
    tour = @emp.tours.create!(send_now: true, from_date: Date.current, to_date: Date.current + 2,
      tour_visits_attributes: [ { visit_date: Date.current, place: "Sagar", planned_activity: "Mtg" } ])
    tour.approve!(by: @am)
    sign_in @emp
    get new_tour_claim_path(tour)
    assert_redirected_to tour_path(tour)
    assert_match "opens on", flash[:alert]
  end

  test "tour claim starts every expense section with a row and keeps PD finance coding off the employee form" do
    tour = @emp.tours.create!(send_now: true, from_date: Date.current - 4, to_date: Date.current - 2,
      tour_visits_attributes: [ { visit_date: Date.current - 4, place: "Sagar", planned_activity: "Mtg" } ])
    tour.approve!(by: @am)

    sign_in @emp
    get new_tour_claim_path(tour)

    assert_response :success
    %w[claim_city_travels claim_local_travels claim_lodgings claim_daily_allowances claim_incidentals].each do |association|
      assert_match "tour_claim[#{association}_attributes]", response.body
    end
    # Each expense section renders one visible row and one row template; the
    # daily travel-detail rows add their own row-level controls as well.
    assert_operator response.body.scan('data-action="nested-rows#addAfter"').size, :>=, 10
    assert_no_match(/>Project<|>Budget Line Item(?: Code)?</, response.body)
  end

  test "local mileage month follows cutoff and HR override" do
    travel_to Date.new(2026, 11, 3) do
      assert_equal "Oct-2026", LocalMileagePeriod.new(@emp).label
      ClaimCutoffRule.create!(user: @emp, cutoff_day: 2, updated_by: @hr)
      assert_equal "Nov-2026", LocalMileagePeriod.new(@emp).label
      assert_equal "Oct-2026", LocalMileagePeriod.new(@am).label
    end
  end

  test "Local Mileage Claim menu opens the B. Local Travel form directly (like live ESS)" do
    sign_in @emp
    get new_tour_path(type: "local")
    assert_redirected_to new_local_mileage_path
    get new_local_mileage_path
    assert_response :success
    assert_no_match "B. Local Travel", response.body               # whole page is the local mileage form
    assert_match "Met. Reading from", response.body
    assert_match "₹/km", response.body
    assert_no_match "Planned activities", response.body          # no visit page in between
    assert_no_match "E. Incidental", response.body
    period = LocalMileagePeriod.new(@emp)

    assert_difference -> { Tour.type_local.count } => 1, -> { TourClaim.count } => 1 do
      post local_mileage_path, params: { commit_action: "save", tour_claim: {
        claim_local_travels_attributes: { "0" => { travel_date: period.from_date, place_from: "HO", place_to: "Bank", travel_mode_id: mode("Four Wheeler").id, meter_from: 100, meter_to: 110 } } } }
    end
    tour = Tour.type_local.last
    assert tour.approved?
    assert_equal [ "self_sanctioned" ], tour.activity_logs.pluck(:action)
    assert_equal 100, tour.tour_claim.local_travel_total.to_i
    assert tour.tour_claim.draft?

    get tours_path(type: "local")
    assert_match "Self-sanctioned", response.body
    assert_no_match "Approved by", response.body

    get new_local_mileage_path                                       # same month again → open the saved claim
    assert_redirected_to edit_tour_claim_path(tour)
  end

  test "local mileage: invalid row keeps the form and creates nothing" do
    sign_in @emp
    assert_no_difference -> { Tour.count } do
      post local_mileage_path, params: { commit_action: "submit", tour_claim: {
        claim_local_travels_attributes: { "0" => { travel_date: "", place_from: "HO", place_to: "", travel_mode_id: mode("Two Wheeler").id, meter_from: 100, meter_to: 110 } } } }
    end
    assert_response :unprocessable_entity
    assert_match "Met. Reading from", response.body
    assert_match "Please fix the following", response.body
  end

  test "approver can Return (employee edits & resends) or Reject (final); remark required" do
    tour = @emp.tours.create!(send_now: true, from_date: Date.current + 3, to_date: Date.current + 4,
      tour_visits_attributes: [ { visit_date: Date.current + 3, place: "Indore", planned_activity: "Mtg" } ])
    sign_in @am
    get approvals_tours_path
    assert_response :success
    get approvals_tour_path(tour)
    assert_match "History (maker", response.body
    assert_match "Approve", response.body
    patch send_back_approvals_tour_path(tour), params: { remark: "" }
    assert tour.reload.submitted?
    patch send_back_approvals_tour_path(tour), params: { remark: "Add more visit detail" }
    assert tour.reload.returned?
    sign_out @am

    sign_in @emp
    get edit_tour_path(tour)
    assert_match "Add more visit detail", response.body
    patch tour_path(tour), params: { commit_action: "send", tour: { general_description: "Updated" } }
    assert tour.reload.submitted?
    sign_out @emp

    sign_in @am
    patch reject_approvals_tour_path(tour), params: { remark: "Not required now" }
    assert tour.reload.rejected?
    sign_out @am
    sign_in @emp
    get edit_tour_path(tour)
    assert_redirected_to root_path   # rejected is final
    assert_equal %w[submitted returned submitted rejected], tour.activity_logs.pluck(:action)
  end
end
