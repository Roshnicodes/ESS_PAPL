# Claim form fields (tour_ta_da)
class MatchLiveClaimFields < ActiveRecord::Migration[8.1]
  def change
    # C. LODGING: first column "DATE" (bill / check-in date) before PLACE / FROM / TO
    add_column :claim_lodgings, :lodging_date, :date

    # Brief detail of travel: DATE | PLACE VISITED | Tour Visit Created DATE | TASKS | ACTION POINTS | Time frame
    add_column :claim_visit_reports, :planned_date, :date
    add_reference :claim_visit_reports, :tour_visit, foreign_key: { on_delete: :nullify }, index: true

    # Mode-of-travel behaviour switches seen on the live form
    add_column :travel_modes, :manual_total, :boolean, null: false, default: false # Public Transport: KM + total typed, meters locked
  end
end
