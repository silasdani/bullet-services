# frozen_string_literal: true

class BuildingPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def assigned?
    user.present?
  end

  def show?
    return false unless user.present?
    return true if user.admin?

    resolver = project_resolver
    return true if resolver&.assigned?

    if (user.contractor? || user.general_contractor?) && !record.work_orders
                                                                .where(is_draft: false, deleted_at: nil)
                                                                .merge(WorkOrder.contractor_visible_status)
                                                                .exists?
      return false
    end

    true
  end

  def create?
    user.present? && user.admin?
  end

  def update?
    return false unless user.present?
    return true if user.admin?

    resolver = project_resolver
    return resolver.can_edit_building? if resolver&.assigned?

    false
  end

  def destroy?
    user.present? && user.admin?
  end

  class Scope < Scope
    def resolve
      if user.contractor? || user.general_contractor?
        scope.joins(:work_orders)
             .where(work_orders: {
                      is_draft: false,
                      deleted_at: nil,
                      status: WorkOrder.statuses.values_at(:pending, :approved, :rejected)
                    })
             .distinct
      elsif user.supervisor?
        # Supervisors see only projects (buildings) they have membership in
        assigned_building_ids = Assignment.where(user_id: user.id).pluck(:building_id)
        return scope.none if assigned_building_ids.empty?

        scope.where(id: assigned_building_ids)
      else
        scope.all
      end
    end
  end

  private

  def project_resolver
    @project_resolver ||= ProjectRoleResolver.new(user: user, building: record)
  end
end
