# frozen_string_literal: true

class WorkOrderPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false unless user.present?
    # Contractors and general contractors can view work orders,
    # but with additional visibility constraints enforced via scope and serializers.
    return true if contractor_or_general_contractor?
    # Supervisors can view work orders they created or in buildings they're assigned to.
    return true if user.supervisor? && supervisor_can_show?

    admin_or_employee_or_owner?
  end

  def supervisor_can_show?
    record.user_id == user.id || supervisor_assigned_to_building?
  end

  def supervisor_assigned_to_building?
    Assignment.exists?(user_id: user.id, building_id: record.building_id)
  end

  def contractor_can_show?
    return false if record.draft? || record.is_archived?
    return true if user.general_contractor?

    active_building_id = contractor_active_building_id
    return record.building_id == active_building_id if active_building_id

    Assignment.exists?(user_id: user.id, building_id: record.building_id)
  end

  def contractor_active_building_id
    active = TimeEntry.clocked_in.for_user(user).includes(:work_order).first
    active&.work_order&.building_id
  end

  def create?
    # Contractors and general contractors cannot create work orders
    return false if user&.contractor? || user&.general_contractor?

    user.present?
  end

  def update?
    return false unless user.present?
    # Contractors and general contractors cannot update work orders.
    return false if contractor_or_general_contractor?
    # Supervisors can update work orders they created or in buildings they're assigned to,
    # but price editing is enforced at the service/serializer layer.
    return supervisor_can_show? if user.supervisor?

    admin_or_employee_or_owner?
  end

  def publish?
    return false unless user.present?
    # Contractors and general contractors cannot publish/unpublish
    return false if contractor_or_general_contractor?
    # Supervisors can publish/unpublish work orders they created or in assigned buildings
    return supervisor_can_show? if user.supervisor?

    user.is_admin? || record.user == user
  end

  def destroy?
    user.present? && (user.is_admin? || record.user == user)
  end

  private

  def contractor_or_general_contractor?
    user.contractor? || user.general_contractor?
  end

  def admin_or_employee_or_owner?
    user.is_admin? || user.is_employee? || record.user == user
  end

  def restore?
    user.present? && (user.is_admin? || record.user == user)
  end

  class Scope < Scope
    # rubocop:disable Metrics/AbcSize
    def resolve
      return scope.none unless user.present?
      return scope.all if user.is_admin?
      return general_contractor_scope if user.general_contractor?
      return supervisor_scope if user.supervisor?
      return contractor_scope if user.contractor?

      owner_scope
    end
    # rubocop:enable Metrics/AbcSize

    def owner_scope
      scope.where(user: user)
    end

    def contractor_scope
      scope
        .where(building_id: user.assigned_buildings.select(:id))
        .where(is_draft: false)
        .contractor_visible_status
    end

    # General contractors see all visible (non-draft) work orders
    def general_contractor_scope
      scope.where(is_draft: false).contractor_visible_status
    end

    def supervisor_scope
      assigned_building_ids = Assignment.where(user_id: user.id).pluck(:building_id)
      scope.where(user_id: user.id).or(scope.where(building_id: assigned_building_ids))
    end
  end
end
