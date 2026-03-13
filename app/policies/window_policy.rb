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
      return supervisor_scope if user.supervisor?

      scope.joins(:work_order).where(work_orders: { user_id: user.id })
    end

    def supervisor_scope
      assigned_building_ids = Assignment.where(user_id: user.id).pluck(:building_id)
      base = scope.joins(:work_order)
      if assigned_building_ids.any?
        base.where(work_orders: { user_id: user.id })
            .or(base.where(work_orders: { building_id: assigned_building_ids }))
      else
        base.where(work_orders: { user_id: user.id })
      end
    end
  end
end
