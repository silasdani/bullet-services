class WindowScheduleRepairPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && (user.is_admin? || user.is_employee? || record.user == user)
  end

  def create?
    user.present?
  end

  def update?
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
      if user.is_admin?
        scope.all
      elsif user.is_employee?
        scope.where(user: user)
      else
        scope.where(user: user)
      end
    end
  end
end
