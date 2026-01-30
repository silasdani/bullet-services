# frozen_string_literal: true

class TimesheetPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def export?
    user.present?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
