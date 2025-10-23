# frozen_string_literal: true

require 'test_helper'

class WindowScheduleRepairPolicyTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @admin = users(:admin)
    @employee = users(:employee)
    @window_schedule_repair = @user.window_schedule_repairs.create!(
      name: 'Test Schedule',
      slug: "test-schedule-#{Time.current.to_i}",
      address: '123 Test St',
      total_vat_included_price: 1000
    )
  end

  def test_scope
    assert_equal [@window_schedule_repair], WindowScheduleRepairPolicy::Scope.new(@user, WindowScheduleRepair).resolve
  end

  def test_show
    assert WindowScheduleRepairPolicy.new(@user, @window_schedule_repair).show?
    assert WindowScheduleRepairPolicy.new(@admin, @window_schedule_repair).show?
    assert WindowScheduleRepairPolicy.new(@employee, @window_schedule_repair).show?
  end

  def test_create
    assert WindowScheduleRepairPolicy.new(@user, WindowScheduleRepair).create?
  end

  def test_update
    assert WindowScheduleRepairPolicy.new(@user, @window_schedule_repair).update?
    assert WindowScheduleRepairPolicy.new(@admin, @window_schedule_repair).update?
    assert WindowScheduleRepairPolicy.new(@employee, @window_schedule_repair).update?
  end

  def test_destroy
    assert WindowScheduleRepairPolicy.new(@user, @window_schedule_repair).destroy?
    assert WindowScheduleRepairPolicy.new(@admin, @window_schedule_repair).destroy?
  end
end
