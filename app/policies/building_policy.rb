# frozen_string_literal: true

class BuildingPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false unless user.present?

    if (user.contractor? || user.general_contractor?) && !record.window_schedule_repairs
                                                                .where(is_draft: false, deleted_at: nil)
                                                                .merge(WindowScheduleRepair.contractor_visible_status)
                                                                .exists?
      return false
    end

    true
  end

  def create?
    user.present?
  end

  def update?
    # Contractors and general contractors cannot update buildings
    return false if user&.contractor? || user&.general_contractor?

    user.present?
  end

  def destroy?
    user.present? && (user.is_admin? || user.is_employee?)
  end

  class Scope < Scope
    def resolve
      # Contractors can see all buildings that have at least one non-draft WRS with approved/rejected/pending status
      # After check-in, they will only see WRS from that building, but can still see all buildings in the list
      if user.contractor? || user.general_contractor?
        # Show all buildings that have at least one non-draft WRS with the right status
        scope.joins(:window_schedule_repairs)
             .where(window_schedule_repairs: {
                      is_draft: false,
                      deleted_at: nil,
                      status: WindowScheduleRepair.statuses.values_at(:pending, :approved, :rejected)
                    })
             .distinct
      else
        # Admins, clients, and surveyors can see all buildings
        scope.all
      end
    end
  end
end
