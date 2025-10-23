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
        sign_in @user
      end

      test 'should get index' do
        get api_v1_window_schedule_repairs_url
        assert_response :success
      end

      test 'should show window_schedule_repair' do
        get api_v1_window_schedule_repair_url(@window_schedule_repair)
        assert_response :success
      end

      test 'should create window_schedule_repair' do
        post api_v1_window_schedule_repairs_url, params: {
          window_schedule_repair: {
            name: 'New Schedule',
            address: '456 New St',
            flat_number: 'Apt 1'
          }
        }

        assert_response :created
      end

      test 'should update window_schedule_repair' do
        patch api_v1_window_schedule_repair_url(@window_schedule_repair), params: {
          window_schedule_repair: { name: 'Updated Schedule' }
        }
        assert_response :success
      end

      test 'should destroy window_schedule_repair' do
        assert_not @window_schedule_repair.deleted?

        delete api_v1_window_schedule_repair_url(@window_schedule_repair)

        assert_response :success
        @window_schedule_repair.reload
        assert @window_schedule_repair.deleted?
      end
    end
  end
end
