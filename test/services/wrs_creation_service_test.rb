require 'test_helper'

class WrsCreationServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @valid_params = {
      name: "Test WRS",
      address: "123 Test St",
      flat_number: "Apt 1",
      windows_attributes: [
        {
          location: "Kitchen",
          tools_attributes: [
            { name: "Glass Panel", price: 100.0 },
            { name: "Installation", price: 50.0 }
          ]
        },
        {
          location: "Living Room",
          tools_attributes: [
            { name: "Frame Repair", price: 75.0 }
          ]
        }
      ]
    }
  end

  test "creates WRS with windows and tools" do
    service = WrsCreationService.new(@user, @valid_params)
    result = service.create

    assert result[:success]
    assert_equal "Test WRS", result[:wrs].name
    assert_equal 2, result[:wrs].windows.count
    assert_equal 3, result[:wrs].windows.joins(:tools).count
    assert_equal 225.0, result[:wrs].total_vat_excluded_price
  end

  test "calculates totals correctly" do
    service = WrsCreationService.new(@user, @valid_params)
    result = service.create

    wrs = result[:wrs]
    assert_equal 225.0, wrs.total_vat_excluded_price
    assert_equal 270.0, wrs.total_vat_included_price # 20% VAT
    assert_equal 270.0, wrs.grand_total
  end

  test "handles invalid params" do
    invalid_params = @valid_params.merge(name: "")
    service = WrsCreationService.new(@user, invalid_params)
    result = service.create

    refute result[:success]
    assert_includes result[:errors], "Name can't be blank"
  end

  test "updates existing WRS" do
    # Create initial WRS
    service = WrsCreationService.new(@user, @valid_params)
    result = service.create
    wrs = result[:wrs]

    # Update WRS
    update_params = {
      name: "Updated WRS",
      windows_attributes: [
        {
          id: wrs.windows.first.id,
          location: "Updated Kitchen",
          tools_attributes: [
            { name: "New Glass", price: 150.0 }
          ]
        }
      ]
    }

    service = WrsCreationService.new(@user, update_params)
    result = service.update(wrs.id)

    assert result[:success]
    assert_equal "Updated WRS", result[:wrs].name
    assert_equal 1, result[:wrs].windows.count
    assert_equal 150.0, result[:wrs].total_vat_excluded_price
  end
end
