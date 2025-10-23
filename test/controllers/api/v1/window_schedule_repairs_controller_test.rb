# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    class WindowScheduleRepairsControllerTest < ActionDispatch::IntegrationTest
      include Devise::Test::IntegrationHelpers

      def setup
        @user = users(:one)
        @window_schedule_repair = @user.window_schedule_repairs.create!(
          name: 'Test Schedule',
          slug: "test-schedule-#{Time.current.to_i}",
          address: '123 Test St',
          total_vat_included_price: 1000
        )
        # Don't use sign_in for API tests - use token auth instead
      end

      test 'should get index' do
        get api_v1_window_schedule_repairs_url, headers: auth_headers(@user)
        assert_response :success
      end

      test 'should show window_schedule_repair' do
        get api_v1_window_schedule_repair_url(@window_schedule_repair),
            headers: auth_headers(@user)
        assert_response :success
      end

      test 'should create window_schedule_repair' do
        assert_difference('WindowScheduleRepair.count') do
          post api_v1_window_schedule_repairs_url, params: {
            window_schedule_repair: {
              name: 'New Schedule',
              slug: 'new-schedule',
              address: '456 New St',
              total_vat_included_price: 2000
            }
          }, headers: { Authorization: "Bearer #{@user.create_new_auth_token}" }
        end
        assert_response :created
      end

      test 'should update window_schedule_repair' do
        patch api_v1_window_schedule_repair_url(@window_schedule_repair), params: {
          window_schedule_repair: { name: 'Updated Schedule' }
        }, headers: { Authorization: "Bearer #{@user.create_new_auth_token}" }
        assert_response :success
      end

      test 'should destroy window_schedule_repair' do
        assert_difference('WindowScheduleRepair.count', -1) do
          delete api_v1_window_schedule_repair_url(@window_schedule_repair),
                 headers: { Authorization: "Bearer #{@user.create_new_auth_token}" }
        end
        assert_response :no_content
      end

      test 'should publish to webflow' do
        # Mock WebflowService to avoid actual API calls
        webflow_service = mock
        webflow_service.stubs(:publish_items).returns(true)
        WebflowService.stubs(:new).returns(webflow_service)

        @window_schedule_repair.update!(webflow_item_id: 'test_item_id')

        post publish_to_webflow_api_v1_window_schedule_repair_url(@window_schedule_repair),
             headers: { Authorization: "Bearer #{@user.create_new_auth_token}" }

        assert_response :success
        @window_schedule_repair.reload
        assert_equal false, @window_schedule_repair.is_draft
        assert_equal false, @window_schedule_repair.is_archived
        assert_not_nil @window_schedule_repair.last_published
      end

      test 'should unpublish from webflow' do
        # Mock WebflowService to avoid actual API calls
        webflow_service = mock
        webflow_service.stubs(:unpublish_items).returns(true)
        WebflowService.stubs(:new).returns(webflow_service)

        @window_schedule_repair.update!(
          webflow_item_id: 'test_item_id',
          is_draft: false,
          is_archived: false
        )

        post unpublish_from_webflow_api_v1_window_schedule_repair_url(@window_schedule_repair),
             headers: { Authorization: "Bearer #{@user.create_new_auth_token}" }

        assert_response :success
        @window_schedule_repair.reload
        assert_equal true, @window_schedule_repair.is_draft
        assert_equal false, @window_schedule_repair.is_archived
      end
    end
  end
end
