# Payment Advice: PD Finance records the bank UTR against an approved claim, one by one
# or in bulk (tick the rows, or upload the filled sheet back).
class AddPaymentAdviceToTourClaims < ActiveRecord::Migration[8.1]
  def change
    add_column :tour_claims, :utr_no,            :string, limit: 60
    add_column :tour_claims, :paid_on,           :date
    add_column :tour_claims, :payment_remark,    :string, limit: 255
    add_column :tour_claims, :utr_updated_at,    :datetime
    add_reference :tour_claims, :utr_updated_by, foreign_key: { to_table: :users }, index: false

    add_index :tour_claims, :utr_no, where: "utr_no IS NOT NULL", name: "idx_claims_utr"
    add_index :tour_claims, :utr_updated_by_id, where: "utr_updated_by_id IS NOT NULL", name: "idx_claims_utr_by"
    # the Payment Advice working list: approved and not yet paid
    add_index :tour_claims, [ :claim_type, :approved_at ],
              where: "(status)::text = 'approved' AND utr_no IS NULL AND deleted_at IS NULL",
              name: "idx_claims_awaiting_payment"

    # a UTR belongs only to a claim Finance has approved
    add_check_constraint :tour_claims, "utr_no IS NULL OR (status)::text = 'approved'", name: "chk_claims_utr_only_approved"
  end
end
