require "test_helper"

class WindowScheduleRepairTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @window_schedule_repair = @user.window_schedule_repairs.build(
      name: "Test Schedule",
      slug: "test-schedule",
      address: "123 Test St",
      total_vat_included_price: 1000
    )
  end

  test "should be valid" do
    assert @window_schedule_repair.valid?
  end

  test "name should be present" do
    @window_schedule_repair.name = nil
    assert_not @window_schedule_repair.valid?
  end

  test "slug should be present" do
    @window_schedule_repair.slug = nil
    assert_not @window_schedule_repair.valid?
  end

  test "slug should be unique" do
    @window_schedule_repair.save
    duplicate = @window_schedule_repair.dup
    assert_not duplicate.valid?
  end

  test "address should be present" do
    @window_schedule_repair.address = nil
    assert_not @window_schedule_repair.valid?
  end

  test "total_vat_included_price should be present" do
    @window_schedule_repair.total_vat_included_price = nil
    assert_not @window_schedule_repair.valid?
  end

  test "total_vat_included_price should be positive" do
    @window_schedule_repair.total_vat_included_price = 0
    assert_not @window_schedule_repair.valid?
  end

  test "should belong to user" do
    @window_schedule_repair.user = nil
    assert_not @window_schedule_repair.valid?
  end

  test "should have many windows" do
    assert_respond_to @window_schedule_repair, :windows
  end

  test "should destroy associated windows" do
    @window_schedule_repair.save
    @window_schedule_repair.windows.create!(location: "Test Location", image: "test.jpg")
    assert_difference 'Window.count', -1 do
      @window_schedule_repair.destroy
    end
  end

  # WRS Concern Tests
  test "should include Wrs concern" do
    assert_respond_to @window_schedule_repair, :to_webflow
    assert_respond_to @window_schedule_repair, :to_webflow_formatted
  end

  test "to_webflow should return correct field mapping" do
    @window_schedule_repair.save
    @window_schedule_repair.update(
      reference_number: "REF123",
      flat_number: "A1",
      address: "Test project address",
      status: :pending
    )

    webflow_data = @window_schedule_repair.to_webflow

    assert_equal "REF123", webflow_data["reference-number"]
    assert_equal "A1", webflow_data["flat-number"]
    assert_equal "Test project address", webflow_data["project-summary"]
    assert_equal "#FFA500", webflow_data["accepted-declined"]
    assert_equal "pending", webflow_data["accepted-decline"]
  end

  test "to_webflow_formatted should return correct structure" do
    @window_schedule_repair.save

    formatted_data = @window_schedule_repair.to_webflow_formatted

    assert_includes formatted_data.keys, :fieldData
    assert_includes formatted_data.keys, :isArchived
    assert_includes formatted_data.keys, :isDraft
    assert_equal false, formatted_data[:isArchived]
    assert_equal false, formatted_data[:isDraft]
    assert_kind_of Hash, formatted_data[:fieldData]
  end

  test "to_webflow should handle windows and tools correctly" do
    @window_schedule_repair.save

    # Create windows with tools
    window1 = @window_schedule_repair.windows.create!(location: "Living Room")
    window1.tools.create!(name: "Glass Repair", price: 150)
    window1.tools.create!(name: "Frame Fix", price: 75)

    window2 = @window_schedule_repair.windows.create!(location: "Kitchen")
    window2.tools.create!(name: "Seal Replacement", price: 200)

    webflow_data = @window_schedule_repair.to_webflow

    assert_equal "Living Room", webflow_data["window-location"]
    assert_equal "Glass Repair\nFrame Fix", webflow_data["window-1-items-2"]
    assert_equal "150\n75", webflow_data["window-1-items-prices-3"]

    assert_equal "Kitchen", webflow_data["window-2-location"]
    assert_equal "Seal Replacement", webflow_data["window-2-items-2"]
    assert_equal "200", webflow_data["window-2-items-prices-3"]
  end

  test "to_webflow should include window images" do
    @window_schedule_repair.save

    # Create a window with an image
    window1 = @window_schedule_repair.windows.create!(location: "Living Room")
    # Note: In a real test, you'd attach an actual image file
    # For now, we'll just test that the field is present

    webflow_data = @window_schedule_repair.to_webflow

    # Should include the window-1-image field
    assert_includes webflow_data.keys, "window-1-image"
    # Should include the main-project-image field (which should be the first window's image)
    assert_includes webflow_data.keys, "main-project-image"
  end

  test "to_webflow should handle missing data gracefully" do
    @window_schedule_repair.save

    webflow_data = @window_schedule_repair.to_webflow

    # Should not include nil values
    assert_nil webflow_data["reference-number"]
    assert_nil webflow_data["flat-number"]
    assert_nil webflow_data["project-summary"]

    # Should include basic required fields
    assert_equal @window_schedule_repair.name, webflow_data["name"]
    assert_equal @window_schedule_repair.slug, webflow_data["slug"]
  end
end
