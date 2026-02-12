# frozen_string_literal: true

module BuildingsWrsListing
  extend ActiveSupport::Concern

  private

  def contractor_checked_in_elsewhere?
    active_building_id = contractor_active_building_id
    active_building_id.present? && active_building_id != @building.id
  end

  def contractor_can_access_building_wrs?
    # General contractors can access any building with visible WRS
    return true if current_user.general_contractor?

    active_building_id = contractor_active_building_id
    return true if active_building_id == @building.id
    return true if contractor_assigned_to_building_work_order?
    return true if should_show_all_work_orders?(current_user)

    false
  end

  def contractor_assigned_to_building_work_order?
    WorkOrderAssignment
      .joins(:work_order)
      .where(user_id: current_user.id, work_orders: { building_id: @building.id })
      .exists?
  end

  def supervisor_can_access_building_wrs?
    return false unless current_user.supervisor?

    # Supervisor can access if they created WRS on this building or are assigned to WRS here
    WindowScheduleRepair.where(building_id: @building.id, user_id: current_user.id).exists? ||
      contractor_assigned_to_building_work_order?
  end

  def contractor_active_building_id
    active = WorkSession.active.for_user(current_user).includes(:work_order).first
    active&.work_order&.building_id
  end

  def render_wrs_checked_in_elsewhere
    render_error(
      message: 'You are checked in at another project. Please check out first.',
      status: :forbidden
    )
  end

  def render_wrs_not_assigned
    render_error(
      message: 'You are not assigned to this project.',
      status: :forbidden
    )
  end

  def wrs_collection_for_building
    scope = @building.window_schedule_repairs
                     .includes(:user, :windows, windows: [:tools, { images_attachments: :blob }])
                     .order(created_at: :desc)
    if current_user.contractor? || current_user.general_contractor?
      scope = scope.where(is_draft: false).contractor_visible_status
    end
    scope
  end

  def serialize_wrs_page(collection)
    collection.map { |wrs| WindowScheduleRepairSerializer.new(wrs, scope: current_user).serializable_hash }
  end
end
