class WindowScheduleRepairPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && (user.admin? || user.employee? || record.user == user)
  end

  def create?
    user.present?
  end

  def update?
    user.present? && (user.admin? || user.employee? || record.user == user)
  end

  def destroy?
    user.present? && (user.admin? || record.user == user)
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
        scope.where(user: user)
      else
        scope.where(user: user)
      end
    end
  end
end
