# chk_tour_claims_status (with finance_query) replaces the older chk_claims_status.
class DropOldClaimStatusCheck < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :tour_claims, name: "chk_claims_status"
  end

  def down
    add_check_constraint :tour_claims, "status IN ('draft','submitted','l1_approved','finance_pending','approved','returned','rejected','cancelled')", name: "chk_claims_status"
  end
end
