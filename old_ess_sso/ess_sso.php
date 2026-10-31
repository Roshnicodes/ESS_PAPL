<?php
/*
 * ess_sso.php – open the OLD ESS (ess.ploughmanagro.com) from the NEW ESS (hr.ploughmanagro.com) without a second login.
 *
 * The new ESS sends the logged-in employee here with a short-lived signed link:
 *   https://ess.ploughmanagro.com/ess_sso.php?emp_code=1752&expires_at=1793330000&signature=<hex>
 *   signature = HMAC-SHA256(secret, "<emp_code>:<expires_at>")   (link is valid for 2 minutes)
 *
 * This is a NEW file – login_proc.php and every other page stay exactly as they are.
 *
 * Setup (3 things):
 *   1. Put the same secret here and in the new ESS (Admin → Masters → IT Tools Settings → Old ESS secret).
 *   2. In the block marked "SAME AS login_proc.php" copy the lines login_proc.php runs AFTER a correct
 *      password (database lookup of the user + the $_SESSION[...] values it sets + its redirect).
 *   3. Copy this file next to login_proc.php.
 */

$ESS_SSO_SECRET = 'PUT_THE_SAME_SECRET_AS_IN_NEW_ESS';   // keep private – never commit a real value to git
$MAX_LINK_AGE   = 300;                                   // seconds (new ESS links live 2 minutes)

function sso_fail($msg) {
    http_response_code(403);
    echo '<p style="font-family:Arial">' . htmlspecialchars($msg) .
         ' <a href="index.php">Login with username and password</a></p>';
    exit;
}

$emp_code   = isset($_GET['emp_code'])   ? trim($_GET['emp_code'])   : '';
$expires_at = isset($_GET['expires_at']) ? (int) $_GET['expires_at'] : 0;
$signature  = isset($_GET['signature'])  ? strtolower(trim($_GET['signature'])) : '';

if ($ESS_SSO_SECRET === '' || $ESS_SSO_SECRET === 'PUT_THE_SAME_SECRET_AS_IN_NEW_ESS') sso_fail('Single sign-on is not set up.');
if ($emp_code === '' || $expires_at === 0 || $signature === '')                          sso_fail('Invalid link.');
if ($expires_at < time() || $expires_at > time() + $MAX_LINK_AGE)                        sso_fail('This link has expired – open it again from the new ESS.');

$expected = hash_hmac('sha256', $emp_code . ':' . $expires_at, $ESS_SSO_SECRET);
if (!hash_equals($expected, $signature))                                                  sso_fail('Invalid link.');

if (session_status() !== PHP_SESSION_ACTIVE) session_start();
session_regenerate_id(true);

/* ======================== SAME AS login_proc.php ========================
 * Copy here what login_proc.php does after the password was found correct, but find the user by
 * $emp_code (the username) WITHOUT checking the password. For example (adjust to the real code):
 *
 *   include 'config.php';                                            // same DB connection file
 *   $stmt = $conn->prepare("SELECT * FROM users WHERE username = ? AND status = 'Active'");
 *   $stmt->bind_param('s', $emp_code);
 *   $stmt->execute();
 *   $user = $stmt->get_result()->fetch_assoc();
 *   if (!$user) sso_fail('Employee ' . $emp_code . ' is not available in the old ESS.');
 *   $_SESSION['username'] = $user['username'];                      // same session keys as login_proc.php
 *   $_SESSION['emp_id']   = $user['id'];
 *   header('Location: dashboard.php');                               // same page login_proc.php opens
 *   exit;
 * ======================================================================= */

sso_fail('Single sign-on is not finished – the "SAME AS login_proc.php" block is still empty.');
