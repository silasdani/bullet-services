# frozen_string_literal: true

# Central resolver for a user's effective role on a specific project/building.
#
# Rules:
#   1. If an Assignment exists for (user, building), return assignment.role.
#   2. Global admins bypass project-role checks (platform-wide privilege),
#      but we still return their assignment role when one exists so the
#      UI can display it.
#   3. If no assignment exists, return nil (no project access).
#
class ProjectRoleResolver
  FIELD_WORKER_ROLES = %w[contractor general_contractor].freeze
  MANAGEMENT_ROLES   = %w[supervisor contract_manager surveyor].freeze

  attr_reader :user, :building

  def initialize(user:, building:)
    @user = user
    @building = building
  end

  # Returns the assignment-level role string, or nil when unassigned.
  def effective_role
    assignment&.role
  end

  def assignment
    return @assignment if defined?(@assignment)

    @assignment = Assignment.find_by(user_id: user.id, building_id: building_id)
  end

  def assigned?
    assignment.present?
  end

  # Convenience predicates scoped to this project.
  def field_worker?
    FIELD_WORKER_ROLES.include?(effective_role)
  end

  def manager?
    MANAGEMENT_ROLES.include?(effective_role)
  end

  def can_create_work_order?
    return true if user.admin?

    %w[supervisor contract_manager].include?(effective_role)
  end

  def can_edit_work_order?(_work_order)
    return true if user.admin?
    return true if effective_role == 'contract_manager'
    return true if effective_role == 'supervisor'

    false
  end

  def can_publish_work_order?
    return true if user.admin?

    %w[supervisor contract_manager].include?(effective_role)
  end

  def can_delete_work_order?(work_order)
    return true if user.admin?
    return true if effective_role == 'contract_manager'
    return true if effective_role == 'supervisor'
    return true if work_order.user_id == user.id && manager?

    false
  end

  def can_check_in?
    field_worker? || manager? || user.admin?
  end

  def can_edit_building?
    return true if user.admin?

    manager?
  end

  def can_edit_schedule_of_condition?
    return true if user.admin?

    %w[supervisor contract_manager].include?(effective_role)
  end

  def can_view_prices?
    user.admin? || effective_role == 'contract_manager'
  end

  def can_assign_users?
    return true if user.admin?

    effective_role == 'contract_manager'
  end

  private

  def building_id
    case building
    when Integer then building
    else building&.id
    end
  end
end
