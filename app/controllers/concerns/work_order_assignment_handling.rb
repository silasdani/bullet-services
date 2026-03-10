# frozen_string_literal: true

module WorkOrderAssignmentHandling
  extend ActiveSupport::Concern

  def perform_assign
    target_user = assignment_target_user

    unless allowed_to_manage_assignment_for?(target_user)
      return render_error(
        message: 'Not authorized to assign this user to a work order',
        status: :forbidden
      )
    end

    assignment = Assignment.find_or_initialize_by(
      user: target_user,
      building: @work_order.building
    )
    assignment.assigned_by_user = current_user
    assignment.role = params[:role] if params[:role].present? && current_user.admin?

    if assignment.save
      render_assign_success(target_user)
    else
      render_error(
        message: 'Failed to assign to project',
        details: assignment.errors.full_messages
      )
    end
  end

  def perform_unassign
    target_user = assignment_target_user

    unless allowed_to_manage_assignment_for?(target_user)
      return render_error(
        message: 'Not authorized to unassign this user from a work order',
        status: :forbidden
      )
    end

    assignment = Assignment.find_by(user: target_user, building: @work_order.building)
    assignment&.destroy

    render_success(
      data: {
        user_id: target_user.id,
        work_order_id: @work_order.id,
        assigned: false
      },
      message: 'Successfully unassigned from project'
    )
  end

  private

  def assignment_target_user
    return current_user unless params[:user_id].present?
    return current_user unless current_user.admin?

    User.find(params[:user_id])
  end

  def allowed_to_manage_assignment_for?(target_user)
    return true if current_user.admin?
    return false unless current_user.contractor?

    target_user.id == current_user.id
  end

  def render_assign_success(target_user)
    render_success(
      data: {
        user_id: target_user.id,
        work_order: WorkOrderSerializer.new(@work_order,
                                            scope: current_user).serializable_hash,
        assigned: true
      },
      message: 'Successfully assigned to work order'
    )
  end
end
