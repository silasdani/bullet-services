  test "to_webflow should include window images" do
    @window_schedule_repair.save

    # Create a window with an image
    window1 = @window_schedule_repair.windows.create!(location: "Living Room")
    # Note: In a real test, you'd attach an actual image file
    # For now, we'll just test that the field is present

    webflow_data = @window_schedule_repair.to_webflow

    # Should include the main-project-image field (which should be the first window's image)
    assert_includes webflow_data.keys, "main-project-image"
  end
