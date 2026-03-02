# frozen_string_literal: true

module OngoingWorkCheckInCheckOut
  extend ActiveSupport::Concern

  private

  def build_ongoing_work_check_in_service
    TimeEntries::CheckInService.new(
      user: current_user,
      work_order: @ongoing_work.work_order,
      ongoing_work: @ongoing_work,
      latitude: params[:latitude],
      longitude: params[:longitude],
      address: params[:address]
    )
  end

  def build_ongoing_work_check_out_service
    TimeEntries::CheckOutService.new(
      user: current_user,
      work_order: @ongoing_work.work_order,
      ongoing_work: @ongoing_work,
      latitude: params[:latitude],
      longitude: params[:longitude],
      address: params[:address]
    )
  end

  def time_entry_payload(entry)
    {
      id: entry.id,
      work_order_id: entry.work_order_id,
      ongoing_work_id: entry.ongoing_work_id,
      starts_at: entry.starts_at,
      ends_at: entry.ends_at,
      start_lat: entry.start_lat,
      start_lng: entry.start_lng,
      end_lat: entry.end_lat,
      end_lng: entry.end_lng,
      start_address: entry.start_address,
      end_address: entry.end_address,
      active: entry.clocked_in?,
      duration_hours: entry.duration_hours,
      duration_minutes: entry.duration_minutes
    }
  end

  def render_check_in_success(service)
    render_success(
      data: time_entry_payload(service.time_entry),
      message: 'Checked in successfully',
      status: :created
    )
  end

  def render_check_out_success(service)
    render_success(
      data: time_entry_payload(service.time_entry).merge(hours_worked: service.hours_worked),
      message: 'Checked out successfully',
      status: :created
    )
  end
end
