# frozen_string_literal: true

class WorkSessionPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    user.present?
  end

  def check_in?
    user.present? && (user.contractor? || user.admin?)
  end

  def check_out?
    user.present? && (user.contractor? || user.admin?)
  end

  def update?
    user.present? && (user.admin? || record.user == user)
  end

  def destroy?
    user.present? && user.admin?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.present?

      case user.role
      when 'admin'
        scope.all
      when 'contractor'
        scope.for_user(user)
      else
        scope.none
      end
    end
  end
end
