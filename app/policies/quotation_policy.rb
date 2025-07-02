class QuotationPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && (user.admin? || user.employee? || record.user == user)
  end

  def create?
    user.employee? || user.admin?
  end

  def update?
    user.present? && (user.admin? || user.employee? || record.user == user)
  end

  def destroy?
    user.employee? || user.admin?
  end

  def send_to_webflow?
    user.employee? || user.admin?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      elsif user.employee?
        scope.all
      else
        scope.where(user: user)
      end
    end
  end
end