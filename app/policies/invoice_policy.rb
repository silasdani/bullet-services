# frozen_string_literal: true

# InvoicePolicy for managing invoice access permissions
class InvoicePolicy < ApplicationPolicy
  def index?
    user.is_admin? || user.is_employee?
  end

  def show?
    user.is_admin? || user.is_employee?
  end

  def create?
    user.is_admin? || user.is_employee?
  end

  def update?
    user.is_admin? || user.is_employee?
  end

  def destroy?
    user.is_admin?
  end

  def csv_import?
    user.is_admin? || user.is_employee?
  end

  class Scope < Scope
    def resolve
      if user.is_admin? || user.is_employee?
        scope.all
      else
        scope.none
      end
    end
  end
end
