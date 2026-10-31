# "Local Mileage Claim" menu – same as live ESS: opens the B. Local Travel claim form straight away.
# The month comes from the cutoff rule; the (self-sanctioned) local tour and its claim are created
# together on the first Save / Send. Approval: L1 → L2 (if set) → PD Finance.
class LocalMileagesController < ApplicationController
  before_action :set_period

  def new
    authorize! :create, Tour
    if (existing = current_user.tours.type_local.live.find_by(claim_month: @period.month))
      claim = existing.tour_claim
      return redirect_to(new_tour_claim_path(existing)) if claim.nil?
      return redirect_to(claim.employee_editable? ? edit_tour_claim_path(existing) : tour_claim_path(existing))
    end
    build_unsaved
    render "tour_claims/edit"
  end

  def create
    authorize! :create, Tour
    Tour.transaction do
      @tour = current_user.tours.create!(tour_type: "local", general_description: "local travel milage claim")
      @claim = TourClaim.build_for(@tour)
      @claim.assign_attributes(claim_params)
      @claim.submitting = params[:commit_action] == "submit"
      @claim.save!
      @claim.submit!(by: current_user) if @claim.submitting?
    end
    redirect_to tours_path(type: "local"),
      notice: @claim.submitting? ? "Local mileage for #{@tour.duration_label} sent to L1 – #{@claim.l1_approver}." : "Local mileage for #{@tour.duration_label} saved."
  rescue ActiveRecord::RecordInvalid => e
    if @tour&.persisted? && @claim
      # tour got rolled back with the claim – show the form again with the typed rows
      @tour = current_user.tours.new(tour_type: "local").tap { |t| t.valid? }
      errors = e.record.errors.full_messages
      kept = @claim.claim_local_travels.map { |l| l.attributes.slice(*%w[travel_date place_from place_to travel_mode_id meter_from meter_to kilometers purpose amount]) }
      @claim = TourClaim.build_for(@tour)
      kept.each { |a| @claim.claim_local_travels.build(a) }
      errors.each { |m| @claim.errors.add(:base, m) }
    else
      build_unsaved
      e.record.errors.full_messages.each { |m| @claim.errors.add(:base, m) }
    end
    @claim.claim_local_travels.build if @claim.claim_local_travels.empty?
    @form_url = local_mileage_path
    render "tour_claims/edit", status: :unprocessable_entity
  end

  private

  def set_period
    @period = LocalMileagePeriod.new(current_user)
  end

  def build_unsaved
    @tour = current_user.tours.new(tour_type: "local", general_description: "local travel milage claim")
    @tour.valid?   # fills claim month / dates from the cutoff rule
    @claim = TourClaim.build_for(@tour)
    @claim.claim_local_travels.build
    @form_url = local_mileage_path
  end

  def claim_params
    params.require(:tour_claim).permit(:bank_account_id, :helmet_declaration,
      claim_local_travels_attributes: %i[id position amount _destroy travel_date place_from place_to travel_mode_id meter_from meter_to kilometers purpose])
  end
end
