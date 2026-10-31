# PAPL ESS – Tour & Claim module (Rails 8 + PostgreSQL)

Tour / TA-DA / Local Mileage module of PAPL ESS (Ploughman Agro Private Limited).

```
bin/setup            # or: bundle && bin/rails db:create db:migrate db:seed
bin/dev              # http://localhost:3000
bin/rails test
```
Demo logins (dev seeds, password `Password@123`): `1025` employee · `AM001` reporting manager · `MIS001` verifier · `FIN001` PD Finance · `HR001` PD HR · `ADMIN`.

## Workflow
| Step | Who | Rule |
|---|---|---|
| Tour Plan → `submitted` | Employee | Visits must be within From/To; overlapping live tours blocked (DB exclusion constraint) |
| `approved` / `rejected` | Reporting manager | Reject needs remark |
| Cancel | Employee | Before **or** after approval, remark mandatory, shows cancelled immediately; blocked once claim is sent |
| Claim form | Employee | Only after approval **and** after tour To-Date (local mileage: right after creation) |
| `submitted → verified` | MIS (`claim_verifier`) | Can set deductions with remark; skipped if no verifier |
| `verified → recommended` | Reporting manager | |
| `recommended → approved` | PD Finance | Project, Budget Line Item, Budget Line Item Code mandatory (suggestions + add new) |
| Return | Any current reviewer | Back to employee to edit & resend |

Local mileage month: up to the cutoff day (default **5**) the previous month is shown, after it the current month.
PD HR changes the day for all employees or employee-wise (`Masters → Local Claim Cutoff Day`).
Per-km rate: PD Finance (`Masters → Per KM Rate`), stored as dated history; claims snapshot the rate used.

## Schema highlights (`db/structure.sql`)
- Every action → `activity_logs` (actor, from/to status, remark, IP, timestamp). Append-only, enforced by a DB trigger.
- Every workflow step also has its own `*_at` / `*_by_id` column on `tours` / `tour_claims`.
- Check constraints for statuses, date order, amounts (`total = amount − deduction`, deduction ≤ amount), approval needs finance coding, cancellation needs remark.
- Partial unique index: one live local-mileage claim per employee per month; one claim per tour.
- Composite indexes on every list/queue (`user_id,status`, `approver_id,status`, `verifier_id,status`, …), case-insensitive unique indexes on masters, trigram indexes for suggestion search.
- `lock_version` + row locks on workflow transitions to stop double approval.
