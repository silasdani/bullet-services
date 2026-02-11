# frozen_string_literal: true

class WindowScheduleRepairPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false unless user.present?
    return true if user.contractor? || user.general_contractor?

    record.user == user || user.is_admin? || user.is_employee?
  end

  def contractor_can_show?
    return false if record.draft? || record.is_archived?
    # General contractors can show any visible WRS (they see all projects)
    return true if user.general_contractor?

    active_building_id = contractor_active_building_id
    return record.building_id == active_building_id if active_building_id

    WorkOrderAssignment.exists?(user_id: user.id, work_order_id: record.id)
  end

  def contractor_active_building_id
    active = WorkSession.active.for_user(user).includes(:work_order).first
    active&.work_order&.building_id
  end

  def create?
    # Contractors and general contractors cannot create WRS
    return false if user&.contractor? || user&.general_contractor?

    user.present?
  end

  def update?
    return false unless user.present?
    return true if user.contractor? || user.general_contractor?

    user.is_admin? || user.is_employee? || record.user == user
  end

  def destroy?
    user.present? && (user.is_admin? || record.user == user)
  end

  def restore?
    user.present? && (user.is_admin? || record.user == user)
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.present?
      return scope.all if user.is_admin?
      # General contractors see all visible (non-draft) WRS
      return scope.where(is_draft: false).contractor_visible_status if user.general_contractor?

      scope.where(user: user)
    end

    private

    def contractor_scope
      scope.where(user: user)
    end
  end
end
