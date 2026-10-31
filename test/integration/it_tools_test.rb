require "test_helper"

class ItToolsTest < ActionDispatch::IntegrationTest
  setup do
    @emp = user("1025")
    @keys = %w[KRA_SSO_SECRET KRA_PORTAL_URL OLD_ESS_SSO_SECRET OLD_ESS_URL]
    @env = ENV.to_h.slice(*@keys)
  end
  teardown { @keys.each { |k| ENV[k] = @env[k] } }

  test "menu shows the IT Tools for every employee" do
    ENV["KRA_SSO_SECRET"] = "kra-secret"
    sign_in @emp
    get authenticated_root_path
    %w[guest_house help_desk training old_ess].each { |t| assert_match it_tool_path(t), response.body }
    assert_no_match "GeoHub", response.body
  end

  test "tools without a link are shown but open nothing" do
    ENV["KRA_SSO_SECRET"] = nil
    sign_in @emp
    get authenticated_root_path
    %w[guest_house help_desk training].each { |t| assert_no_match it_tool_path(t), response.body }
    assert_match it_tool_path("old_ess"), response.body
    assert_match "link is not set up yet", response.body
  end

  test "not connected yet → friendly message, no redirect away" do
    ENV["KRA_SSO_SECRET"] = nil
    sign_in @emp
    get it_tool_path("help_desk")
    assert_redirected_to authenticated_root_path
    assert_match "not connected", flash[:alert]
  end

  test "Help Desk link is signed exactly the way Key Result checks it" do
    ENV["KRA_SSO_SECRET"] = "kra-secret"; ENV["KRA_PORTAL_URL"] = "https://kra.ploughmanagro.com"
    sign_in @emp
    get it_tool_path("help_desk")
    uri = URI.parse(response.location)
    q = URI.decode_www_form(uri.query).to_h
    assert_equal "kra.ploughmanagro.com", uri.host
    assert_equal "/users/sign_in/#{@emp.emp_code}", uri.path
    assert_equal "help_desk", q["to"]
    # key-result Users::SessionsController#external_sign_in_payload: "code:to:expires_at"
    expected = OpenSSL::HMAC.hexdigest("SHA256", "kra-secret", "#{@emp.emp_code}:help_desk:#{q['expires_at']}")
    assert_equal expected, q["signature"]
    assert_in_delta 2.minutes.from_now.to_i, q["expires_at"].to_i, 5
  end

  test "unknown tool is not routed" do
    sign_in @emp
    get "/it-tools/payroll"
    assert_response :not_found
    get "/it-tools/geohub"
    assert_response :not_found
  end

  test "admin saves secrets in IT Tools Settings (stored encrypted) and the link works" do
    ENV["KRA_SSO_SECRET"] = nil
    sign_in user("ADMIN")
    get masters_it_tool_settings_path
    assert_response :success
    patch masters_it_tool_settings_path, params: { settings: { KRA_PORTAL_URL: "https://kra.ploughmanagro.com", KRA_SSO_SECRET: "from-admin" } }
    raw = AppSetting.find_by!(key: "KRA_SSO_SECRET").value
    refute_includes raw, "from-admin"
    assert_equal "from-admin", AppSetting.get("KRA_SSO_SECRET")
    get it_tool_path("training")
    q = URI.decode_www_form(URI.parse(response.location).query).to_h
    assert_equal OpenSSL::HMAC.hexdigest("SHA256", "from-admin", "ADMIN:training:#{q['expires_at']}"), q["signature"]
    # blank secret field keeps the saved value
    patch masters_it_tool_settings_path, params: { settings: { KRA_SSO_SECRET: "" } }
    assert_equal "from-admin", AppSetting.get("KRA_SSO_SECRET")
  end

  test "only admin opens IT Tools Settings" do
    sign_in @emp
    get masters_it_tool_settings_path
    assert_redirected_to root_path
  end

  test "Old ESS: login page until its secret is set, then a signed link ess_sso.php checks" do
    ENV["OLD_ESS_SSO_SECRET"] = nil
    sign_in @emp
    get it_tool_path("old_ess")
    assert_redirected_to "https://ess.asaindia.org/papl/index.php"
    ENV["OLD_ESS_SSO_SECRET"] = "old-secret"
    get it_tool_path("old_ess")
    uri = URI.parse(response.location)
    q = URI.decode_www_form(uri.query).to_h
    assert_equal [ "ess.asaindia.org", "/papl/ess_sso.php" ], [ uri.host, uri.path ]
    assert_equal @emp.emp_code, q["emp_code"]
    # old_ess_sso/ess_sso.php: hash_hmac('sha256', "$emp_code:$expires_at", secret)
    assert_equal OpenSSL::HMAC.hexdigest("SHA256", "old-secret", "#{@emp.emp_code}:#{q['expires_at']}"), q["signature"]
  end
end
