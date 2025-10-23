# frozen_string_literal: true

require 'test_helper'

class WrsCreationServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @valid_params = {
      name: 'Test WRS',
      address: '123 Test St',
      flat_number: 'Apt 1',
      windows_attributes: [
        {
          location: 'Kitchen',
          tools_attributes: [
            { name: 'Glass Panel', price: 100 },
            { name: 'Installation', price: 50 }
          ]
        },
        {
          location: 'Living Room',
          tools_attributes: [
            { name: 'Frame Repair', price: 75 }
          ]
        }
      ]
    }
  end

  test 'creates WRS with windows and tools' do
    service = Wrs::CreationService.new(user: @user, params: @valid_params)
    result = service.call

    assert result[:success]
    assert_equal 'Test WRS', result[:wrs].name
    assert_equal 2, result[:wrs].windows.count
    assert_equal 3, result[:wrs].windows.joins(:tools).count
    assert_equal 225.0, result[:wrs].total_vat_excluded_price
  end

  test 'calculates totals correctly' do
    service = Wrs::CreationService.new(user: @user, params: @valid_params)
    result = service.call

    wrs = result[:wrs]
    assert_equal 225.0, wrs.total_vat_excluded_price
    assert_equal 270.0, wrs.total_vat_included_price # 20% VAT
    assert_equal 270.0, wrs.grand_total
  end

  test 'handles invalid params' do
    invalid_params = @valid_params.merge(name: '')
    service = Wrs::CreationService.new(user: @user, params: invalid_params)
    result = service.call

    refute result[:success]
    assert_includes service.errors, "Name can't be blank"
  end

  test 'updates existing WRS' do
    # Create initial WRS
    service = Wrs::CreationService.new(user: @user, params: @valid_params)
    result = service.call
    wrs = result[:wrs]

    # Update WRS using UpdateService
    update_params = {
      name: 'Updated WRS',
      windows_attributes: [
        {
          id: wrs.windows.first.id,
          location: 'Updated Kitchen',
          tools_attributes: [
            { name: 'New Glass', price: 150 }
          ]
        }
      ]
    }

    update_service = Wrs::UpdateService.new(wrs: wrs, params: update_params)
    result = update_service.call

    assert result[:success]
    assert_equal 'Updated WRS', result[:wrs].name
    assert_equal 1, result[:wrs].windows.count
    assert_equal 150.0, result[:wrs].total_vat_excluded_price
  end

  test 'creates WRS with image upload' do
    # Create a mock file upload
    mock_file = mock('uploaded_file')
    mock_file.expect(:present?, true)
    mock_file.expect(:respond_to?, true, [:content_type])
    mock_file.expect(:content_type, 'image/jpeg')
    mock_file.expect(:original_filename, 'test.jpg')

    params_with_image = @valid_params.deep_dup
    params_with_image[:windows_attributes][0][:image] = mock_file

    service = Wrs::CreationService.new(user: @user, params: params_with_image)
    result = service.call

    assert result[:success]
    assert_equal 2, result[:wrs].windows.count
    # NOTE: In test environment, ActiveStorage might not fully process the mock file
    # but this test ensures the service doesn't crash with image parameters
  end
end
