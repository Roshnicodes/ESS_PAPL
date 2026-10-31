# Old ESS → open from the new ESS without login

The new ESS (hr.ploughmanagro.com) has a menu **IT Tools → Old ESS**. Until this is set up it simply opens
https://ess.ploughmanagro.com (normal login page). After setup the employee lands in the old ESS already logged in.

## What the old ESS team does (only adds one new file – nothing existing changes)

1. Open `ess_sso.php` and fill the block **"SAME AS login_proc.php"**: copy the lines `login_proc.php` runs after a
   correct password (find the user, set the same `$_SESSION` values, redirect to the same page) – but find the user
   by `$emp_code` without checking the password.
2. Put a long random secret in `$ESS_SSO_SECRET` (the new ESS shows one in *IT Tools Settings*).
3. Copy `ess_sso.php` to the old ESS site root, next to `login_proc.php`.
4. Give the same secret to the new ESS admin → *Masters → IT Tools Settings → Old ESS secret* → Save.

## Link the new ESS sends

    https://ess.ploughmanagro.com/ess_sso.php?emp_code=1752&expires_at=<unix time + 2 min>&signature=<hex>
    signature = HMAC-SHA256(secret, "<emp_code>:<expires_at>")

Only links signed with the shared secret and not older than a few minutes are accepted, so nobody can open
another employee's old ESS by changing the code in the address.
