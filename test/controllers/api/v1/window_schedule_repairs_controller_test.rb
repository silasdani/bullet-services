require "test_helper"

class Api::V1::WindowScheduleRepairsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
    @window_schedule_repair = @user.window_schedule_repairs.create!(
      name: "Test Schedule",
      slug: "test-schedule",
      address: "123 Test St",
      total_vat_included_price: 1000
    )
    sign_in @user
  end

  test "should get index" do
    get api_v1_window_schedule_repairs_url, headers: { 'Authorization': "Bearer #{@user.create_new_auth_token}" }
    assert_response :success
  end

  test "should show window_schedule_repair" do
    get api_v1_window_schedule_repair_url(@window_schedule_repair), headers: { 'Authorization': "Bearer #{@user.create_new_auth_token}" }
    assert_response :success
  end

  test "should create window_schedule_repair" do
    assert_difference('WindowScheduleRepair.count') do
      post api_v1_window_schedule_repairs_url, params: {
        window_schedule_repair: {
          name: "New Schedule",
          slug: "new-schedule",
          address: "456 New St",
          total_vat_included_price: 2000
        }
      }, headers: { 'Authorization': "Bearer #{@user.create_new_auth_token}" }
    end
    assert_response :created
  end

  test "should update window_schedule_repair" do
    patch api_v1_window_schedule_repair_url(@window_schedule_repair), params: {
      window_schedule_repair: { name: "Updated Schedule" }
    }, headers: { 'Authorization': "Bearer #{@user.create_new_auth_token}" }
    assert_response :success
  end

  test "should destroy window_schedule_repair" do
    assert_difference('WindowScheduleRepair.count', -1) do
      delete api_v1_window_schedule_repair_url(@window_schedule_repair), headers: { 'Authorization': "Bearer #{@user.create_new_auth_token}" }
    end
    assert_response :no_content
  end
end
