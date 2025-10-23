# frozen_string_literal: true

require 'test_helper'

class WindowTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @window_schedule_repair = @user.window_schedule_repairs.create!(
      name: 'Test Schedule',
      slug: "test-schedule-#{Time.current.to_i}",
      address: '123 Test St',
      total_vat_included_price: 1000
    )
    @window = @window_schedule_repair.windows.build(
      location: 'Test Location'
    )
  end

  test 'should be valid' do
    assert @window.valid?
  end

  test 'location should be present' do
    @window.location = nil
    assert_not @window.valid?
  end

  test 'should belong to window_schedule_repair' do
    @window.window_schedule_repair = nil
    assert_not @window.valid?
  end

  test 'should be destroyed when window_schedule_repair is destroyed' do
    @window.save
    assert_difference 'Window.count', -1 do
      @window_schedule_repair.destroy
    end
  end
end
