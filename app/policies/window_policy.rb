# frozen_string_literal: true

class WindowPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && (user.is_admin? || user.is_employee? || record.window_schedule_repair.user == user)
  end

  def create?
    user.present?
  end

  def update?
    user.present? && (user.is_admin? || user.is_employee? || record.window_schedule_repair.user == user)
  end

  def destroy?
    user.present? && (user.is_admin? || record.window_schedule_repair.user == user)
  end

  class Scope < Scope
    def resolve
      if user.is_admin?
        scope.all
      else
        scope.joins(:window_schedule_repair).where(WindowScheduleRepair.table_name => { user_id: user.id })
      end
    end
  end
end
