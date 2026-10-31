ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  self.use_transactional_tests = true

  setup do
    Rails.application.load_seed if User.none?
    give_bank_accounts!
  end

  # Claims cannot be sent without a bank account – every seeded employee gets one in tests.
  def give_bank_accounts!
    User.where.not(id: BankAccount.select(:user_id)).find_each do |u|
      bank_account_for(u)
    end
  end

  def bank_account_for(u, number: "1234567#{u.id.to_s.rjust(5, '0')}")
    a = u.bank_accounts.new(account_holder_name: u.name, bank_name: "State Bank of India", account_number: number, ifsc_code: "SBIN0001234")
    a.passbook.attach(io: File.open(Rails.root.join("test/fixtures/files/passbook.png")), filename: "passbook.png", content_type: "image/png")
    a.save!
    a
  end

  def user(code) = User.find_by!(emp_code: code)

  # "Tasks Accomplished" is mandatory in the travel report before a claim is sent
  def with_tasks(claim)
    claim.claim_visit_reports.each do |r|
      r.tasks_accomplished ||= "Field visit done"
      r.action_points ||= "Follow up with SHG"
      r.time_frame ||= "1 week"
      r.remark ||= "OK"
    end
    claim
  end
  def mode(name) = TravelMode.find_by!(name: name)
end

module FinanceCodingTestHelper
  def finance_mapping(project_name: "Tata Trust", line_item_name: "Travel", code_name: "T-1")
    project = Project.find_or_create_by!(name: project_name)
    line_item = BudgetLineItem.find_or_create_by!(name: line_item_name)
    code = BudgetLineItemCode.find_or_create_by!(name: code_name)
    ProjectBudgetLineItem.find_or_create_by!(project: project, budget_line_item: line_item, budget_line_item_code: code)
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include FinanceCodingTestHelper
end

ActiveSupport::TestCase.include FinanceCodingTestHelper
