# frozen_string_literal: true

class WindowPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false unless user.present?

    wo = record.work_order
    return supervisor_can_access?(wo) if user.supervisor?

    user.admin? || wo.user == user
  end

  def create?
    user.present?
  end

  def update?
    return false unless user.present?

    wo = record.work_order
    return supervisor_can_access?(wo) if user.supervisor?

    user.admin? || wo.user == user
  end

  def destroy?
    return false unless user.present?

    wo = record.work_order
    return supervisor_can_access?(wo) if user.supervisor?

    user.admin? || wo.user == user
  end

  private

  def supervisor_can_access?(work_order)
    work_order.user_id == user.id || supervisor_assigned_to_building?(work_order)
  end

  def supervisor_assigned_to_building?(work_order)
    Assignment.exists?(user_id: user.id, building_id: work_order.building_id)
  end

  class Scope < Scope
    def resolve
      return scope.all if user.admin?

      scope.joins(:work_order).where(work_orders: { user_id: user.id })
    end
  end
end
