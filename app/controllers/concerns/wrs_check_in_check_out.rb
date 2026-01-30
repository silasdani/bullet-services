# frozen_string_literal: true

module WrsCheckInCheckOut
  extend ActiveSupport::Concern

  private

  def build_check_in_service
    CheckIns::CheckInService.new(
      user: current_user,
      window_schedule_repair: @window_schedule_repair,
      latitude: params[:latitude],
      longitude: params[:longitude],
      address: params[:address]
    )
  end

  def build_check_out_service
    CheckIns::CheckOutService.new(
      user: current_user,
      window_schedule_repair: @window_schedule_repair,
      latitude: params[:latitude],
      longitude: params[:longitude],
      address: params[:address]
    )
  end

  def check_in_payload(record)
    {
      id: record.id,
      action: record.action,
      timestamp: record.timestamp,
      window_schedule_repair_id: record.window_schedule_repair_id,
      latitude: record.latitude,
      longitude: record.longitude,
      address: record.address
    }
  end

  def check_out_payload(record, service)
    check_in_payload(record).merge(hours_worked: service.hours_worked)
  end

  def render_check_in_success(service)
    render_success(data: check_in_payload(service.check_in), message: 'Checked in successfully', status: :created)
  end

  def render_check_out_success(service)
    render_success(
      data: check_out_payload(service.check_out, service),
      message: 'Checked out successfully',
      status: :created
    )
  end
end
