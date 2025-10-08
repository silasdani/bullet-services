require "test_helper"

class WindowPolicyTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @admin = users(:admin)
    @employee = users(:employee)
    @window_schedule_repair = @user.window_schedule_repairs.create!(
      name: "Test Schedule",
      slug: "test-schedule",
      address: "123 Test St",
      total_vat_included_price: 1000
    )
    @window = @window_schedule_repair.windows.create!(
      location: "Test Location",
      image: "test.jpg"
    )
  end

  def test_scope
    assert_equal [ @window ], WindowPolicy::Scope.new(@user, Window).resolve
  end

  def test_show
    assert WindowPolicy.new(@user, @window).show?
    assert WindowPolicy.new(@admin, @window).show?
    assert WindowPolicy.new(@employee, @window).show?
  end

  def test_create
    assert WindowPolicy.new(@user, Window).create?
  end

  def test_update
    assert WindowPolicy.new(@user, @window).update?
    assert WindowPolicy.new(@admin, @window).update?
    assert WindowPolicy.new(@employee, @window).update?
  end

  def test_destroy
    assert WindowPolicy.new(@user, @window).destroy?
    assert WindowPolicy.new(@admin, @window).destroy?
  end
end
