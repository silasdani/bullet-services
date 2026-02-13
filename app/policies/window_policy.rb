# frozen_string_literal: true

class WindowPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false unless user.present?

    wo = record.work_order
    return supervisor_can_access?(wo) if user.supervisor?

    user.is_admin? || user.is_employee? || wo.user == user
  end

  def create?
    user.present?
  end

  def update?
    return false unless user.present?

    wo = record.work_order
    return supervisor_can_access?(wo) if user.supervisor?

    user.is_admin? || user.is_employee? || wo.user == user
  end

  def destroy?
    return false unless user.present?

    wo = record.work_order
    return supervisor_can_access?(wo) if user.supervisor?

    user.is_admin? || wo.user == user
  end

  private

  def supervisor_can_access?(work_order)
    work_order.user_id == user.id || supervisor_assigned_to_building?(work_order)
  end

  def supervisor_assigned_to_building?(work_order)
    WorkOrderAssignment.where(user_id: user.id).joins(:work_order)
                       .where(work_orders: { building_id: work_order.building_id }).exists?
  end

  class Scope < Scope
    def resolve
      if user.is_admin?
        scope.all
      else
        scope.joins(:work_order).where(work_orders: { user_id: user.id })
      end
    end
  end
end
