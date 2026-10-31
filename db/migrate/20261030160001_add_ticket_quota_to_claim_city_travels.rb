# A. Travel (city to city) rows on a train also say Normal / Tatkal – Tatkal needs the mode's Tatkal approver (COO).
class AddTicketQuotaToClaimCityTravels < ActiveRecord::Migration[8.1]
  def change
    add_column :claim_city_travels, :ticket_quota, :string, limit: 10, null: false, default: "normal"
    add_check_constraint :claim_city_travels, "ticket_quota IN ('normal','tatkal')", name: "chk_claim_city_travels_quota"
  end
end
