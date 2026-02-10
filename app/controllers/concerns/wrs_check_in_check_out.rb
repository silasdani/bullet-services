# frozen_string_literal: true

module WrsCheckInCheckOut
  extend ActiveSupport::Concern

  private

  def build_check_in_service
    WorkSessions::CheckInService.new(
      user: current_user,
      work_order: @window_schedule_repair,
      latitude: params[:latitude],
      longitude: params[:longitude],
      address: params[:address]
    )
  end

  def build_check_out_service
    WorkSessions::CheckOutService.new(
      user: current_user,
      work_order: @window_schedule_repair,
      latitude: params[:latitude],
      longitude: params[:longitude],
      address: params[:address]
    )
  end

  def work_session_payload(session)
    {
      id: session.id,
      work_order_id: session.work_order_id,
      checked_in_at: session.checked_in_at,
      checked_out_at: session.checked_out_at,
      latitude: session.latitude,
      longitude: session.longitude,
      address: session.address,
      active: session.active?
    }
  end

  def render_check_in_success(service)
    render_success(
      data: work_session_payload(service.work_session),
      message: 'Checked in successfully',
      status: :created
    )
  end

  def render_check_out_success(service)
    render_success(
      data: work_session_payload(service.work_session).merge(hours_worked: service.hours_worked),
      message: 'Checked out successfully',
      status: :created
    )
  end
end
