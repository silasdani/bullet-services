require "test_helper"

class WindowScheduleRepairAutoSyncTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  test "new WRS should default to draft" do
    wrs = WindowScheduleRepair.new(
      name: "Test WRS",
      address: "123 Test Street",
      flat_number: "Apt 1",
      user: @user
    )

    # Trigger validations
    wrs.valid?

    assert wrs.is_draft, "New WRS should default to draft"
    assert_not wrs.is_archived, "New WRS should not be archived"
  end

  test "should_auto_sync_to_webflow? returns true for draft WRS" do
    wrs = WindowScheduleRepair.create!(
      name: "Test WRS",
      address: "123 Test Street",
      flat_number: "Apt 1",
      user: @user,
      is_draft: true
    )

    assert wrs.send(:should_auto_sync_to_webflow?),
           "Should auto-sync draft WRS"
  end

  test "should_auto_sync_to_webflow? returns true for unsynced WRS" do
    wrs = WindowScheduleRepair.create!(
      name: "Test WRS",
      address: "123 Test Street",
      flat_number: "Apt 1",
      user: @user,
      is_draft: false,
      webflow_item_id: nil
    )

    assert wrs.send(:should_auto_sync_to_webflow?),
           "Should auto-sync WRS without webflow_item_id"
  end

  test "should_auto_sync_to_webflow? returns false for published WRS" do
    wrs = WindowScheduleRepair.create!(
      name: "Test WRS",
      address: "123 Test Street",
      flat_number: "Apt 1",
      user: @user,
      is_draft: false,
      webflow_item_id: "webflow-123"
    )

    assert_not wrs.send(:should_auto_sync_to_webflow?),
               "Should NOT auto-sync published WRS"
  end

  test "should_auto_sync_to_webflow? returns false for deleted WRS" do
    wrs = WindowScheduleRepair.create!(
      name: "Test WRS",
      address: "123 Test Street",
      flat_number: "Apt 1",
      user: @user,
      is_draft: true
    )
    wrs.soft_delete!

    assert_not wrs.send(:should_auto_sync_to_webflow?),
               "Should NOT auto-sync deleted WRS"
  end

  test "creating WRS should queue auto-sync job" do
    assert_enqueued_with(job: AutoSyncToWebflowJob) do
      WindowScheduleRepair.create!(
        name: "Test WRS",
        address: "123 Test Street",
        flat_number: "Apt 1",
        user: @user,
        is_draft: true
      )
    end
  end

  test "updating draft WRS should queue auto-sync job" do
    wrs = WindowScheduleRepair.create!(
      name: "Test WRS",
      address: "123 Test Street",
      flat_number: "Apt 1",
      user: @user,
      is_draft: true
    )

    assert_enqueued_with(job: AutoSyncToWebflowJob) do
      wrs.update!(name: "Updated Test WRS")
    end
  end

  test "updating published WRS should not queue auto-sync job" do
    wrs = WindowScheduleRepair.create!(
      name: "Test WRS",
      address: "123 Test Street",
      flat_number: "Apt 1",
      user: @user,
      is_draft: false,
      webflow_item_id: "webflow-123"
    )

    assert_no_enqueued_jobs(only: AutoSyncToWebflowJob) do
      wrs.update!(name: "Updated Test WRS")
    end
  end

  test "draft? method returns correct status" do
    # Draft with no webflow_item_id
    wrs1 = WindowScheduleRepair.new(is_draft: true)
    assert wrs1.draft?

    # Published with webflow_item_id
    wrs2 = WindowScheduleRepair.new(is_draft: false, webflow_item_id: "123")
    assert_not wrs2.draft?

    # No webflow_item_id (never synced)
    wrs3 = WindowScheduleRepair.new(is_draft: false, webflow_item_id: nil)
    assert wrs3.draft?
  end

  test "published? method returns correct status" do
    # Published
    wrs1 = WindowScheduleRepair.new(
      is_draft: false,
      is_archived: false,
      webflow_item_id: "123"
    )
    assert wrs1.published?

    # Draft
    wrs2 = WindowScheduleRepair.new(
      is_draft: true,
      is_archived: false,
      webflow_item_id: "123"
    )
    assert_not wrs2.published?

    # Archived
    wrs3 = WindowScheduleRepair.new(
      is_draft: false,
      is_archived: true,
      webflow_item_id: "123"
    )
    assert_not wrs3.published?
  end
end
