# frozen_string_literal: true

module BuildingsWorkOrderListing
  extend ActiveSupport::Concern

  private

  def contractor_checked_in_elsewhere?
    active_building_id = contractor_active_building_id
    active_building_id.present? && active_building_id != @building.id
  end

  def contractor_can_access_building_work_orders?
    # General contractors can access any building with visible work orders
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

  def supervisor_can_access_building_work_orders?
    return false unless current_user.supervisor?

    WorkOrder.where(building_id: @building.id, user_id: current_user.id).exists? ||
      contractor_assigned_to_building_work_order?
  end

  def contractor_active_building_id
    active = WorkSession.active.for_user(current_user).includes(:work_order).first
    active&.work_order&.building_id
  end

  def render_work_order_checked_in_elsewhere
    render_error(
      message: 'You are checked in at another project. Please check out first.',
      status: :forbidden
    )
  end

  def render_work_order_not_assigned
    render_error(
      message: 'You are not assigned to this project.',
      status: :forbidden
    )
  end

  def work_order_collection_for_building
    scope = @building.work_orders
                     .includes(:user, :windows, windows: [:tools, { images_attachments: :blob }])
                     .order(created_at: :desc)
    if current_user.contractor? || current_user.general_contractor?
      scope = scope.where(is_draft: false).contractor_visible_status
    end
    scope
  end

  def serialize_work_order_page(collection)
    collection.map { |wo| WorkOrderSerializer.new(wo, scope: current_user).serializable_hash }
  end
end
