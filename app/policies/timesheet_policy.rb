# frozen_string_literal: true

class TimesheetPolicy < ApplicationPolicy
  def index?
    user.present? && (user.admin? || user.contract_manager?)
  end

  def export?
    user.present? && (user.admin? || user.contract_manager?)
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
