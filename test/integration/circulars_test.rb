require "test_helper"

class CircularsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = user("ADMIN"); @emp = user("1025"); @other = user("AM001")
    @file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/passbook.png"), "image/png")
  end

  test "admin publishes an IOM for all employees and everyone is notified" do
    sign_in @admin
    get new_masters_circular_path
    assert_response :success

    assert_difference "Circular.count", 1 do
      post masters_circulars_path, params: {
        circular: { topic_type: "iom", topic: "Office timing change", description: "New timing from 01-Dec.",
                    audience: "all", active: "1", attachments: [ @file ] },
        send_notification: "1"
      }
    end
    c = Circular.last
    assert_redirected_to masters_circulars_path
    assert c.type_iom?
    assert_equal 1, c.attachments.size
    assert c.to_all?

    perform_enqueued_jobs_now
    assert_equal User.active.count, Notification.where(notifiable: c).count
    assert Notification.exists?(user: @emp, notifiable: c, kind: "circular_published")
    assert c.reload.notified?
  end

  test "a selected-employees circular reaches only the chosen people" do
    sign_in @admin
    post masters_circulars_path, params: {
      circular: { topic_type: "circular", topic: "Audit visit", audience: "selected", active: "1" },
      recipient_ids: [ @emp.id ], send_notification: "1"
    }
    c = Circular.last
    assert_equal [ @emp.id ], c.recipients.pluck(:id)
    perform_enqueued_jobs_now
    assert Notification.exists?(user: @emp, notifiable: c)
    refute Notification.exists?(user: @other, notifiable: c)

    sign_in @emp
    get circulars_path
    assert_match "Audit visit", response.body
    sign_in @other
    get circulars_path
    assert_no_match "Audit visit", response.body
    get circular_path(c)
    assert_redirected_to authenticated_root_path
  end

  test "the admin list and the employee pages render" do
    c = Circular.create!(topic_type: "iom", topic: "Annual audit", description: "Please keep bills ready.",
                         audience: "all", created_by: @admin)
    c.attachments.attach(io: File.open(Rails.root.join("test/fixtures/files/passbook.png")), filename: "note.png", content_type: "image/png")
    sign_in @admin
    [ masters_circulars_path, new_masters_circular_path, edit_masters_circular_path(c), circulars_path, circular_path(c) ].each do |p|
      get p
      assert_response :success, p
    end
    assert_match "Annual audit", response.body
    assert_match "note.png", response.body
  end

  test "editing the recipient list adds and removes people" do
    sign_in @admin
    post masters_circulars_path, params: { circular: { topic_type: "iom", topic: "Team note", audience: "selected", active: "1" },
                                           recipient_ids: [ @emp.id ] }
    c = Circular.last
    assert_equal [ @emp.id ], c.recipients.pluck(:id).sort

    # swap the employee for somebody else
    patch masters_circular_path(c), params: { circular: { topic_type: "iom", topic: "Team note", audience: "selected", active: "1" },
                                              recipient_ids: [ @other.id ] }
    assert_equal [ @other.id ], c.reload.recipients.pluck(:id).sort

    # switching to "all employees" clears the list
    patch masters_circular_path(c), params: { circular: { topic_type: "iom", topic: "Team note", audience: "all", active: "1" } }
    assert c.reload.to_all?
    assert_empty c.circular_recipients.reload
  end

  test "selected audience with nobody ticked is rejected" do
    sign_in @admin
    assert_no_difference "Circular.count" do
      post masters_circulars_path, params: { circular: { topic_type: "iom", topic: "Nobody", audience: "selected", active: "1" } }
    end
    assert_response :unprocessable_entity
    assert_match "Choose at least one employee", response.body
  end

  test "deactivating hides it from employees but keeps it for admin" do
    c = Circular.create!(topic_type: "circular", topic: "Holiday list 2027", audience: "all", created_by: @admin)
    sign_in @emp
    get circulars_path
    assert_match "Holiday list 2027", response.body

    sign_in @admin
    patch toggle_masters_circular_path(c)
    follow_redirect!   # consume the admin's flash so it cannot leak into the next assertion
    refute c.reload.active?

    sign_in @emp
    get circulars_path
    assert_no_match "Holiday list 2027", response.body
    get circular_path(c)
    assert_redirected_to authenticated_root_path
  end

  test "an employee can open an attachment of a circular addressed to them, others cannot" do
    c = Circular.create!(topic_type: "iom", topic: "Policy", audience: "selected", created_by: @admin,
                         circular_recipients: [ CircularRecipient.new(user: @emp) ])
    c.attachments.attach(io: File.open(Rails.root.join("test/fixtures/files/passbook.png")), filename: "policy.png", content_type: "image/png")
    id = c.attachments.first.id

    sign_in @emp
    get attachment_circular_path(c, attachment_id: id)
    assert_response :success
    assert_equal "image/png", response.media_type

    sign_in @other
    get attachment_circular_path(c, attachment_id: id)
    assert_redirected_to authenticated_root_path
  end

  test "editing keeps the files already attached and adds the new one" do
    sign_in @admin
    post masters_circulars_path, params: { circular: { topic_type: "iom", topic: "Rates", audience: "all", active: "1",
      attachments: [ @file ] } }
    c = Circular.last
    assert_equal 1, c.attachments.size
    first_id = c.attachments.first.id

    # an edit that changes only the topic must not drop the file
    patch masters_circular_path(c), params: { circular: { topic_type: "iom", topic: "Rates (revised)", audience: "all", active: "1" } }
    assert_equal [ first_id ], c.reload.attachments.map(&:id)
    assert_equal "Rates (revised)", c.topic

    # a second upload is added to the first, not swapped for it
    patch masters_circular_path(c), params: { circular: { topic_type: "iom", topic: "Rates (revised)", audience: "all", active: "1",
      attachments: [ Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/passbook.png"), "image/png") ] } }
    assert_equal 2, c.reload.attachments.size

    # "Remove" ticked against one file takes that one away
    patch masters_circular_path(c), params: { circular: { topic_type: "iom", topic: "Rates (revised)", audience: "all", active: "1" },
      remove_attachment_ids: [ first_id ] }
    assert_equal 1, c.reload.attachments.size
    refute_includes c.attachments.map(&:id), first_id
  end

  test "an ordinary employee cannot reach the admin screens" do
    sign_in @emp
    get masters_circulars_path
    assert_redirected_to authenticated_root_path
    post masters_circulars_path, params: { circular: { topic_type: "iom", topic: "Sneaky", audience: "all" } }
    assert_redirected_to authenticated_root_path
    assert_nil Circular.find_by(topic: "Sneaky")
  end

  private

  # CircularNotifyJob runs with the :async adapter outside tests; in tests it is enqueued.
  def perform_enqueued_jobs_now
    CircularNotifyJob.new.perform(Circular.last.id, @admin.id)
  end
end
