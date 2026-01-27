# frozen_string_literal: true

class BuildingPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false unless user.present?
    # Contractors cannot see buildings that only have draft WRSes
    if user.contractor?
      return false unless record.window_schedule_repairs.where(is_draft: false, deleted_at: nil).exists?
    end
    true
  end

  def create?
    user.present?
  end

  def update?
    user.present?
  end

  def destroy?
    user.present? && (user.is_admin? || user.is_employee?)
  end

  class Scope < Scope
    def resolve
      # Contractors cannot see buildings that only have draft WRSes
      if user.contractor?
        # Only show buildings that have at least one non-draft WRS
        scope.joins(:window_schedule_repairs)
             .where(window_schedule_repairs: { is_draft: false, deleted_at: nil })
             .distinct
      else
        # Admins, clients, and surveyors can see all buildings
        scope.all
      end
    end
  end
end
