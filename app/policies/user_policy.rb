# frozen_string_literal: true

# UserPolicy for managing user access permissions
class UserPolicy < ApplicationPolicy
  def index?
    user.is_admin?
  end

  def show?
    user.is_admin? || record == user
  end

  def create?
    user.is_admin?
  end

  def update?
    user.is_admin? || record == user
  end

  def destroy?
    user.is_admin? || record == user
  end

  # Custom action for getting current user profile
  def me?
    user.present?
  end

  class Scope < Scope
    def resolve
      if user.is_admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end
