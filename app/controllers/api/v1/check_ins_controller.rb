# frozen_string_literal: true

module Api
  module V1
    class CheckInsController < Api::V1::BaseController
      before_action :set_window_schedule_repair, only: %i[check_in check_out]
      before_action :set_check_in, only: [:show]

      # POST /api/v1/window_schedule_repairs/:window_schedule_repair_id/check_in
      def check_in
        authorize CheckIn, :check_in?
        authorize @window_schedule_repair

        service = build_check_in_service
        service.call

        if service.success?
          render_check_in_success(service)
        else
          render_check_in_error(service)
        end
      end

      # POST /api/v1/window_schedule_repairs/:window_schedule_repair_id/check_out
      def check_out
        authorize CheckIn, :check_out?
        authorize @window_schedule_repair

        service = build_check_out_service
        service.call

        if service.success?
          render_check_out_success(service)
        else
          render_check_out_error(service)
        end
      end

      # GET /api/v1/check_ins/:id
      def show
        authorize @check_in
        render_success(
          data: {
            id: @check_in.id,
            user_id: @check_in.user_id,
            window_schedule_repair_id: @check_in.window_schedule_repair_id,
            action: @check_in.action,
            timestamp: @check_in.timestamp,
            latitude: @check_in.latitude,
            longitude: @check_in.longitude,
            address: @check_in.address,
            created_at: @check_in.created_at
          }
        )
      end

      # GET /api/v1/check_ins
      def index
        authorize CheckIn
        check_ins = load_check_ins

        render_success(
          data: serialize_check_ins(check_ins),
          meta: pagination_meta(check_ins)
        )
      end

      private

      def set_window_schedule_repair
        @window_schedule_repair = WindowScheduleRepair.find(params[:window_schedule_repair_id])
      end

      def set_check_in
        @check_in = CheckIn.find(params[:id])
      end

      def serialize_check_in(check_in)
        {
          id: check_in.id,
          action: check_in.action,
          timestamp: check_in.timestamp,
          latitude: check_in.latitude,
          longitude: check_in.longitude,
          address: check_in.address
        }
      end

      def serialize_check_out(check_out, hours_worked)
        {
          id: check_out.id,
          action: check_out.action,
          timestamp: check_out.timestamp,
          latitude: check_out.latitude,
          longitude: check_out.longitude,
          address: check_out.address,
          hours_worked: hours_worked
        }
      end

      def build_check_in_service
        CheckIns::CheckInService.new(
          user: current_user,
          window_schedule_repair: @window_schedule_repair,
          latitude: params[:latitude],
          longitude: params[:longitude],
          address: params[:address],
          timestamp: params[:timestamp]
        )
      end

      def render_check_in_success(service)
        render_success(
          data: serialize_check_in(service.check_in),
          message: 'Checked in successfully',
          status: :created
        )
      end

      def render_check_in_error(service)
        render_error(
          message: 'Failed to check in',
          details: service.errors
        )
      end

      def build_check_out_service
        CheckIns::CheckOutService.new(
          user: current_user,
          window_schedule_repair: @window_schedule_repair,
          latitude: params[:latitude],
          longitude: params[:longitude],
          address: params[:address],
          hourly_rate: params[:hourly_rate],
          timestamp: params[:timestamp]
        )
      end

      def render_check_out_success(service)
        hours_worked = service.calculate_hours_worked
        render_success(
          data: serialize_check_out(service.check_out, hours_worked),
          message: 'Checked out successfully'
        )
      end

      def render_check_out_error(service)
        render_error(
          message: 'Failed to check out',
          details: service.errors
        )
      end

      def load_check_ins
        CheckIn.where(user: current_user)
               .includes(:window_schedule_repair)
               .order(timestamp: :desc)
               .page(@page)
               .per(@per_page)
      end

      def serialize_check_ins(check_ins)
        check_ins.map do |ci|
          {
            id: ci.id,
            window_schedule_repair_id: ci.window_schedule_repair_id,
            window_schedule_repair_name: ci.window_schedule_repair.name,
            action: ci.action,
            timestamp: ci.timestamp,
            latitude: ci.latitude,
            longitude: ci.longitude,
            address: ci.address
          }
        end
      end
    end
  end
end
