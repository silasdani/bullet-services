# frozen_string_literal: true

class WindowScheduleRepairPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false unless user.present?
    return true unless user.contractor?

    contractor_can_show?
  end

  def contractor_can_show?
    return false if record.draft? || record.is_archived?

    active_building_id = contractor_active_building_id
    return record.building_id == active_building_id if active_building_id

    BuildingAssignment.exists?(user_id: user.id, building_id: record.building_id)
  end

  def contractor_active_building_id
    active = CheckIn.active_for(user, nil).includes(:window_schedule_repair).first
    active&.window_schedule_repair&.building_id
  end

  def create?
    # Contractors cannot create WRS
    return false if user&.contractor?

    user.present?
  end

  def update?
    # Contractors cannot update WRS
    return false if user&.contractor?

    user.present? && (user.is_admin? || user.is_employee? || record.user == user)
  end

  def destroy?
    user.present? && (user.is_admin? || record.user == user)
  end

  def restore?
    user.present? && (user.is_admin? || record.user == user)
  end

  def send_to_webflow?
    user.present? && user.webflow_access
  end

  def publish_to_webflow?
    user.present? && user.webflow_access
  end

  def unpublish_from_webflow?
    user.present? && user.webflow_access
  end

  class Scope < Scope
    def resolve
      return scope.all unless user&.contractor?

      contractor_scope
    end

    private

    def contractor_scope
      base = scope.where(is_draft: false, is_archived: false).contractor_visible_status
      building_id = contractor_active_building_id
      return base.where(building_id: building_id) if building_id
      return base if should_show_all_buildings?(user)

      base.where(building_id: BuildingAssignment.where(user_id: user.id).select(:building_id))
    end

    def contractor_active_building_id
      active = CheckIn.active_for(user, nil).includes(:window_schedule_repair).first
      active&.window_schedule_repair&.building_id
    end

    def should_show_all_buildings?(user)
      # Check if user has any building assignments
      assigned_building_ids = BuildingAssignment.where(user_id: user.id).pluck(:building_id)

      # If no assignments, show all buildings
      return true if assigned_building_ids.empty?

      # Check if all assigned buildings have only completed WRS
      # Get all WRS from assigned buildings that are not completed
      non_completed_wrs_count = WindowScheduleRepair
                                .where(building_id: assigned_building_ids)
                                .where(is_draft: false, is_archived: false)
                                .contractor_visible_status
                                .count

      # If all assigned buildings have only completed WRS, show all buildings
      non_completed_wrs_count.zero?
    end
  end
end
