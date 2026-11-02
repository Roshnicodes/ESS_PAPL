# PAPL: PD Finance approves a claim without Project / BLI / BLI Code – an approved claim only needs its approval time.
class DropFinanceCodingRequirementOnClaims < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :tour_claims, name: "chk_claims_finance_coding_on_approval"
    add_check_constraint :tour_claims, "status::text <> 'approved'::text OR approved_at IS NOT NULL",
      name: "chk_claims_approved_at_on_approval"
  end

  def down
    remove_check_constraint :tour_claims, name: "chk_claims_approved_at_on_approval"
    add_check_constraint :tour_claims,
      "status::text <> 'approved'::text OR (project_id IS NOT NULL AND budget_line_item_id IS NOT NULL AND budget_line_item_code_id IS NOT NULL AND approved_at IS NOT NULL)",
      name: "chk_claims_finance_coding_on_approval"
  end
end
