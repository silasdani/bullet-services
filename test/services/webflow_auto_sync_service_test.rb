require "test_helper"

class WebflowAutoSyncServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @wrs = WindowScheduleRepair.create!(
      name: "Test WRS",
      address: "123 Test Street",
      flat_number: "Apt 1",
      user: @user,
      is_draft: true
    )
  end

  test "should sync draft WRS without webflow_item_id" do
    service = Webflow::AutoSyncService.new(wrs: @wrs)

    # Mock the ItemService
    mock_item_service = Minitest::Mock.new
    mock_item_service.expect :create_item, { "id" => "webflow-123" }, [ Hash ]

    Webflow::ItemService.stub :new, mock_item_service do
      result = service.call

      assert result[:success], "Sync should succeed for draft WRS without webflow_item_id"
      assert_equal "created", result[:action]
      assert_equal "webflow-123", result[:webflow_item_id]
    end

    mock_item_service.verify
  end

  test "should sync draft WRS with webflow_item_id" do
    @wrs.update_column(:webflow_item_id, "webflow-123")

    service = Webflow::AutoSyncService.new(wrs: @wrs)

    # Mock the ItemService
    mock_item_service = Minitest::Mock.new
    mock_item_service.expect :update_item, true, [ String, Hash ]

    Webflow::ItemService.stub :new, mock_item_service do
      result = service.call

      assert result[:success], "Sync should succeed for draft WRS with webflow_item_id"
      assert_equal "updated", result[:action]
    end

    mock_item_service.verify
  end

  test "should not sync published WRS" do
    @wrs.update_columns(is_draft: false, webflow_item_id: "webflow-123")

    service = Webflow::AutoSyncService.new(wrs: @wrs)
    result = service.call

    assert_not result[:success], "Should not sync published WRS"
    assert_equal "not_draft", result[:reason]
  end

  test "should not sync deleted WRS" do
    @wrs.soft_delete!

    service = Webflow::AutoSyncService.new(wrs: @wrs)
    result = service.call

    assert_not result[:success], "Should not sync deleted WRS"
    assert_equal "record_deleted", result[:reason]
  end

  test "should not sync WRS with missing required fields" do
    @wrs.update_column(:name, nil)

    service = Webflow::AutoSyncService.new(wrs: @wrs)
    result = service.call

    assert_not result[:success], "Should not sync WRS with missing required fields"
    assert_equal "invalid_data", result[:reason]
  end

  test "should handle WebflowApiError gracefully" do
    service = Webflow::AutoSyncService.new(wrs: @wrs)

    # Mock the ItemService to raise an error
    mock_item_service = Minitest::Mock.new
    error = WebflowApiError.new("API Error", 500, "Internal Server Error")
    mock_item_service.expect :create_item, proc { raise error }, [ Hash ]

    Webflow::ItemService.stub :new, mock_item_service do
      result = service.call

      assert_not result[:success], "Should handle API errors gracefully"
      assert_equal "API Error", result[:error]
      assert_equal 500, result[:status_code]
    end
  end
end
