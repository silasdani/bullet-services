# frozen_string_literal: true

class BuildingPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    user.present?
  end

  def update?
    user.present? && (user.is_admin? || user.is_employee?)
  end

  def destroy?
    user.present? && (user.is_admin? || user.is_employee?)
  end

  class Scope < Scope
    def resolve
      # All authenticated users can see all buildings
      scope.all
    end
  end
end
