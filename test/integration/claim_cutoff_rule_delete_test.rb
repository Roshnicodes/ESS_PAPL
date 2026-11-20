require "test_helper"

class ClaimCutoffRuleDeleteTest < ActionDispatch::IntegrationTest
  test "removing an employee override works and keeps its history" do
    admin = user("ADMIN")
    sign_in admin
    Current.user = admin
    rule = ClaimCutoffRule.create!(user: user("1025"), cutoff_day: 10, updated_by: admin)
    assert rule.activity_logs.exists?

    delete masters_claim_cutoff_rule_path(rule)
    assert_redirected_to masters_claim_cutoff_rules_path
    assert_not ClaimCutoffRule.exists?(rule.id)
    assert ActivityLog.where(trackable_type: "ClaimCutoffRule", trackable_id: rule.id, action: "cutoff_removed").exists?

    follow_redirect!
    assert_response :success
  end
end
