# frozen_string_literal: true

class WindowPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false unless user.present?

    wo = record.work_order
    return wo.user_id == user.id if user.supervisor?

    user.is_admin? || user.is_employee? || wo.user == user
  end

  def create?
    user.present?
  end

  def update?
    return false unless user.present?

    wo = record.work_order
    return wo.user_id == user.id if user.supervisor?

    user.is_admin? || user.is_employee? || wo.user == user
  end

  def destroy?
    return false unless user.present?
    return record.work_order.user_id == user.id if user.supervisor?

    user.is_admin? || record.work_order.user == user
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
