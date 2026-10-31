# PAPL ESS mail page for krai

PAPL ESS (https://hr.ploughmanagro.com – Tour Plan, TA/DA claim, Local Mileage) sends every
notification as an email through **one krai page, `ess_notification.aspx`** – the same way
Apurti (`nemail.aspx`) and the KRA portal (`asakra_notification.aspx`) already use krai.
The ESS server calls the page with GET parameters; the page sends one HTML mail to `to_email`.
`mail_type` tells the page which mail it is (heading, colour, button).

## Files

| File | What it is |
| --- | --- |
| `ess_notification.aspx` | The one page the ESS server calls |
| `App_Code/EssMail.cs` | Builds the HTML mail and sends it |
| `web.config.sample` | Settings to merge into krai's `web.config` |

## Setup

1. Copy `ess_notification.aspx` to the krai site root (next to `nemail.aspx` / `asakra_notification.aspx`).
2. Copy `App_Code/EssMail.cs` to the site's `App_Code` folder.
   In a Web Application project (not a Web Site), add it to the project with Build Action = Compile and rebuild.
3. Merge `web.config.sample` into krai's `web.config`: SMTP details (the same notification mail id / SMTP
   as the KRA page can be used), sender, and the `<location>` entry if krai uses a login.
4. Put the ESS server's public IP **143.110.255.154** in `EssAllowedIps`, so only the ESS server can send
   mails through the page.
5. Requires .NET Framework 4.0 or newer.

## Parameters (same as the KRA / Guest House pages)

`to_email, to_name, subject, message, link, employee_name, employee_code, quarter, month,
reviewer_role, reviewer_name, action, remarks, mail_type`

- `to_email` is required; the others may be empty (`quarter` and `month` are always empty for ESS).
- `subject` is the mail subject (starts with "PAPL ESS:").
- `message` is the main text; it already contains the tour reference, tour dates / local-mileage month and
  claim amount, e.g. `… Ref: TR-2026-000017 | Tour Plan 23/10/2026 to 27/10/2026 | Claim amount: Rs. 1012.50`.
- `reviewer_name` = the person who did the action, `reviewer_role` = Employee / Approver.
- `action` = pending, forwarded, approved, returned, rejected, cancelled, deleted, closed or information
  (please accept all of these – do not limit it to pending/approved/rejected).
- `remarks` = the remark written by the approver / Finance (may be empty).
- `link` becomes a button. It must start with `https://hr.ploughmanagro.com`.
- All values are HTML-encoded. The page writes the "Dear <to_name>," greeting itself.

## mail_type values

| mail_type | Sent to | When | Colour |
| --- | --- | --- | --- |
| tour_pending | L1 / L2 / COO / Director | Tour plan waiting for their approval | Blue |
| tour_forwarded | Employee | Tour forwarded to the next approver | Blue |
| tour_approved | Employee, earlier approvers | Tour plan approved | Green |
| tour_returned | Employee, earlier approvers | Tour returned for correction | Orange |
| tour_rejected | Employee, earlier approvers | Tour rejected | Red |
| tour_cancelled | Approvers | Employee cancelled the tour | Grey |
| tour_deleted | Employee | Admin deleted the tour | Grey |
| tour_info | Administration | Approved tour uses Personal Four Wheeler (information only) | Grey |
| claim_pending | L1 / L2 / COO / Director / Finance | Claim waiting for their approval | Blue |
| claim_forwarded | Employee | Claim forwarded to the next approver | Blue |
| claim_approved | Employee, L1, L2 | Claim approved by Finance | Green |
| claim_returned | Employee | Claim returned for correction | Orange |
| claim_rejected | Employee | Claim rejected | Red |
| claim_closed | Earlier approvers | Claim returned / rejected (information) | Grey |
| claim_query | L1 / L2 | Finance asked a question – reply needed | Orange |
| claim_query_info | Employee | Finance asked L1 / L2 about the claim | Grey |
| claim_info | Administration | Local mileage with Four Wheeler approved (information only) | Grey |

An unknown or empty `mail_type` still sends the mail with a general heading.

## Response

| Result | HTTP | Body |
| --- | --- | --- |
| Mail sent | 200 | `{"success":true,"message":"Email sent"}` |
| to_email missing / invalid | 400 | `{"success":false,...}` |
| Caller IP not allowed | 403 | `{"success":false,...}` |
| SMTP error | 500 | `{"success":false,"message":"Email not sent: ..."}` |

The ESS server treats anything other than 200 with `"success":true` as a failure and logs it.

## Test

Open in a browser after putting your own email in place of `YOUR_EMAIL` (more links in `ESS_krai_test_links.txt`):

```
https://krai.ploughmanagro.com/ess_notification.aspx?to_email=YOUR_EMAIL%40ploughmanagro.com&to_name=Rajesh+Kumar&subject=PAPL+ESS%3A+Tour+for+your+approval+%28L1%29&message=Priya+Sharma+sent+Tour+plan+%2823%2F10%2F2026+to+27%2F10%2F2026%29.+Ref%3A+TR-2026-000017+%7C+Tour+Plan+23%2F10%2F2026+to+27%2F10%2F2026&link=https%3A%2F%2Fhr.ploughmanagro.com%2Fapprovals%2Ftours%2F17&employee_name=Priya+Sharma&employee_code=1752&quarter=&month=&reviewer_role=Employee&reviewer_name=Priya+Sharma&action=pending&remarks=&mail_type=tour_pending
```

The page should show `{"success":true,"message":"Email sent"}` and the mail should arrive.

## After the page is live

Tell the ESS team. They set `ESS_MAIL_RELAY_URL=https://krai.ploughmanagro.com/ess_notification.aspx`
on the ESS server and restart it – every ESS notification then also goes as an email.
