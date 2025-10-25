require "test_helper"

class Api::V1::WindowsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
    @window_schedule_repair = @user.window_schedule_repairs.create!(
      name: "Test Schedule",
      slug: "test-schedule-#{Time.current.to_i}",
      address: "123 Test St",
      total_vat_included_price: 1000
    )
    @window = @window_schedule_repair.windows.create!(
      location: "Test Location"
    )
    sign_in @user
  end

  test "should get index" do
    get api_v1_windows_url, headers: { "Authorization": "Bearer #{@user.create_new_auth_token}" }
    assert_response :success
  end

  test "should show window" do
    get api_v1_window_url(@window), headers: { "Authorization": "Bearer #{@user.create_new_auth_token}" }
    assert_response :success
  end

  test "should create window" do
    assert_difference("Window.count") do
      post api_v1_windows_url, params: {
        window: {
          location: "New Location",
          window_schedule_repair_id: @window_schedule_repair.id
        }
      }, headers: { "Authorization": "Bearer #{@user.create_new_auth_token}" }
    end
    assert_response :created
  end

  test "should update window" do
    patch api_v1_window_url(@window), params: {
      window: { location: "Updated Location" }
    }, headers: { "Authorization": "Bearer #{@user.create_new_auth_token}" }
    assert_response :success
  end

  test "should destroy window" do
    assert_difference("Window.count", -1) do
      delete api_v1_window_url(@window), headers: { "Authorization": "Bearer #{@user.create_new_auth_token}" }
    end
    assert_response :no_content
  end
end
