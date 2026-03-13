# frozen_string_literal: true

class WorkOrderPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false unless user.present?
    return true if user.admin?
    return true if contractor_or_general_contractor?
    return true if user.supervisor? && supervisor_can_show?

    admin_or_employee_or_owner?
  end

  def supervisor_can_show?
    record.user_id == user.id || supervisor_assigned_to_building?
  end

  def supervisor_assigned_to_building?
    Assignment.exists?(user_id: user.id, building_id: record.building_id)
  end

  def contractor_can_show?
    return false if record.draft? || record.is_archived?
    return true if user.general_contractor?

    active_building_id = contractor_active_building_id
    return record.building_id == active_building_id if active_building_id

    Assignment.exists?(user_id: user.id, building_id: record.building_id)
  end

  def contractor_active_building_id
    active = TimeEntry.clocked_in.for_user(user).includes(:work_order).first
    active&.work_order&.building_id
  end

  def create?
    return false unless user.present?

    resolver = project_resolver
    return resolver.can_create_work_order? if resolver&.assigned?

    # Fallback to global role when no building context yet
    return false if user.contractor? || user.general_contractor?

    true
  end

  def update?
    return false unless user.present?
    return true if user.admin?

    resolver = project_resolver
    return resolver.can_edit_work_order?(record) if resolver&.assigned?

    return false if contractor_or_general_contractor?
    return supervisor_can_show? if user.supervisor?

    admin_or_employee_or_owner?
  end

  def publish?
    return false unless user.present?
    return true if user.admin?

    resolver = project_resolver
    return resolver.can_publish_work_order? if resolver&.assigned?

    return false if contractor_or_general_contractor?
    return supervisor_can_show? if user.supervisor?

    user.is_admin? || record.user == user
  end

  def destroy?
    return false unless user.present?
    return true if user.admin?

    resolver = project_resolver
    return resolver.can_delete_work_order?(record) if resolver&.assigned?

    user.is_admin? || record.user == user
  end

  private

  def project_resolver
    return nil unless record.respond_to?(:building_id)
    return nil if record.building_id.nil?

    @project_resolver ||= ProjectRoleResolver.new(user: user, building: record.building_id)
  end

  def contractor_or_general_contractor?
    user.contractor? || user.general_contractor?
  end

  def admin_or_employee_or_owner?
    user.is_admin? || user.is_employee? || record.user == user
  end

  def restore?
    user.present? && (user.is_admin? || record.user == user)
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.present?
      return scope.all if user.is_admin?
      return general_contractor_scope if user.general_contractor?
      return supervisor_scope if user.supervisor?
      return contractor_scope if user.contractor?

      owner_scope
    end

    def owner_scope
      scope.where(user: user)
    end

    # Contractors see work orders in assigned buildings. Visibility depends on project assignment role:
    # managers (supervisor/contract_manager/surveyor) see all including drafts;
    # field workers (contractor/general_contractor) see only published.
    def contractor_scope
      manager_ids = building_ids_for_role(ProjectRoleResolver::MANAGEMENT_ROLES)
      field_worker_ids = building_ids_for_role(ProjectRoleResolver::FIELD_WORKER_ROLES)

      scopes = []
      scopes << scope.where(building_id: manager_ids) if manager_ids.any?
      if field_worker_ids.any?
        scopes << scope.where(building_id: field_worker_ids).where(is_draft: false).contractor_visible_status
      end

      scopes.any? ? scopes.reduce(:or) : scope.none
    end

    def building_ids_for_role(roles)
      Assignment.where(user_id: user.id, role: roles).pluck(:building_id)
    end

    def general_contractor_scope
      scope.where(is_draft: false).contractor_visible_status
    end

    def supervisor_scope
      assigned_building_ids = Assignment.where(user_id: user.id).pluck(:building_id)
      scope.where(user_id: user.id).or(scope.where(building_id: assigned_building_ids))
    end
  end
end
