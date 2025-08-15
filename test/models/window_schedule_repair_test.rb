require "test_helper"

class WindowScheduleRepairTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @window_schedule_repair = @user.window_schedule_repairs.build(
      name: "Test Schedule",
      slug: "test-schedule",
      address: "123 Test St",
      total_vat_included_price: 1000
    )
  end

  test "should be valid" do
    assert @window_schedule_repair.valid?
  end

  test "name should be present" do
    @window_schedule_repair.name = nil
    assert_not @window_schedule_repair.valid?
  end

  test "slug should be present" do
    @window_schedule_repair.slug = nil
    assert_not @window_schedule_repair.valid?
  end

  test "slug should be unique" do
    @window_schedule_repair.save
    duplicate = @window_schedule_repair.dup
    assert_not duplicate.valid?
  end

  test "address should be present" do
    @window_schedule_repair.address = nil
    assert_not @window_schedule_repair.valid?
  end

  test "total_vat_included_price should be present" do
    @window_schedule_repair.total_vat_included_price = nil
    assert_not @window_schedule_repair.valid?
  end

  test "total_vat_included_price should be positive" do
    @window_schedule_repair.total_vat_included_price = 0
    assert_not @window_schedule_repair.valid?
  end

  test "should belong to user" do
    @window_schedule_repair.user = nil
    assert_not @window_schedule_repair.valid?
  end

  test "should have many windows" do
    assert_respond_to @window_schedule_repair, :windows
  end

  test "should destroy associated windows" do
    @window_schedule_repair.save
    @window_schedule_repair.windows.create!(location: "Test Location", image: "test.jpg")
    assert_difference 'Window.count', -1 do
      @window_schedule_repair.destroy
    end
  end
end
