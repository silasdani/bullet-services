class WindowPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && (user.admin? || user.employee? || record.window_schedule_repair.user == user)
  end

  def create?
    user.present?
  end

  def update?
    user.present? && (user.admin? || user.employee? || record.window_schedule_repair.user == user)
  end

  def destroy?
    user.present? && (user.admin? || record.window_schedule_repair.user == user)
  end

  # RailsAdmin specific methods
  def dashboard?
    user.admin?
  end

  def export?
    user.admin?
  end

  def history?
    user.admin?
  end

  def show_in_app?
    user.admin?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      elsif user.employee?
        scope.joins(:window_schedule_repair).where(window_schedule_repairs: { user: user })
      else
        scope.joins(:window_schedule_repair).where(window_schedule_repairs: { user: user })
      end
    end
  end
end
