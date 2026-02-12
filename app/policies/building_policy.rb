# frozen_string_literal: true

class BuildingPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false unless user.present?

    if (user.contractor? || user.general_contractor?) && !record.work_orders
                                                                .where(is_draft: false, deleted_at: nil)
                                                                .merge(WorkOrder.contractor_visible_status)
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
      # Contractors can see all buildings that have at least one non-draft work order with approved/rejected/pending status
      if user.contractor? || user.general_contractor?
        scope.joins(:work_orders)
             .where(work_orders: {
                      is_draft: false,
                      deleted_at: nil,
                      status: WorkOrder.statuses.values_at(:pending, :approved, :rejected)
                    })
             .distinct
      elsif user.supervisor?
        scope.all
      else
        scope.all
      end
    end
  end
end
