# frozen_string_literal: true

module Api
  module V1
    class WindowScheduleRepairsController < Api::V1::BaseController
      before_action :set_window_schedule_repair, only: %i[show update destroy restore]

      def index
        authorize WindowScheduleRepair

        wrs_collection = policy_scope(WindowScheduleRepair)
                         .includes(:user, :windows, windows: %i[tools image_attachment])
                         .ransack(params[:q])
                         .result
                         .page(@page)
                         .per(@per_page)

        render_success(
          data: WindowScheduleRepairSerializer.new(wrs_collection).serializable_hash,
          meta: pagination_meta(wrs_collection)
        )
      end

      def show
        authorize @window_schedule_repair

        render_success(
          data: WindowScheduleRepairSerializer.new(@window_schedule_repair).serializable_hash
        )
      end

      def create
        authorize WindowScheduleRepair

        service = Wrs::CreationService.new(
          user: current_user,
          params: window_schedule_repair_params
        )

        result = service.call

        if result[:success]
          render_success(
            data: WindowScheduleRepairSerializer.new(result[:wrs]).serializable_hash,
            message: 'WRS created successfully'
          )
        else
          render_error(
            message: 'Failed to create WRS',
            details: service.errors
          )
        end
      end

      def update
        authorize @window_schedule_repair

        service = Wrs::UpdateService.new(
          wrs: @window_schedule_repair,
          params: window_schedule_repair_params
        )

        result = service.call

        if result[:success]
          render_success(
            data: WindowScheduleRepairSerializer.new(result[:wrs]).serializable_hash,
            message: 'WRS updated successfully'
          )
        else
          render_error(
            message: 'Failed to update WRS',
            details: service.errors
          )
        end
      end

      def destroy
        authorize @window_schedule_repair

        @window_schedule_repair.soft_delete!

        render_success(
          message: 'WRS deleted successfully'
        )
      end

      def restore
        authorize @window_schedule_repair

        @window_schedule_repair.restore!

        render_success(
          data: WindowScheduleRepairSerializer.new(@window_schedule_repair).serializable_hash,
          message: 'WRS restored successfully'
        )
      end

      private

      def set_window_schedule_repair
        # For restore action, we need to find deleted records too
        if action_name == 'restore'
          @window_schedule_repair = WindowScheduleRepair.with_deleted
                                                        .includes(:user, :windows, windows: %i[tools image_attachment])
                                                        .find(params[:id])
        else
          @window_schedule_repair = WindowScheduleRepair.includes(:user, :windows, windows: %i[tools image_attachment])
                                                        .find(params[:id])
        end
      end

      def window_schedule_repair_params
        # Handle both JSON and FormData
        if request.content_type&.include?('multipart/form-data')
          # FormData parameters
          params.permit(
            :name, :slug, :webflow_collection_id, :webflow_item_id, :reference_number,
            :address, :flat_number, :details,
            :total_vat_excluded_price, :status, :status_color, :grand_total,
            images: [],
            windows_attributes: [
              :id, :location, :image, :_destroy,
              { tools_attributes: %i[id name price _destroy] }
            ]
          )
        else
          # JSON parameters
          params.require(:window_schedule_repair).permit(
            :name, :slug, :webflow_collection_id, :webflow_item_id, :reference_number,
            :address, :flat_number, :details,
            :total_vat_excluded_price, :status, :status_color, :grand_total,
            images: [],
            windows_attributes: [
              :id, :location, :image, :_destroy,
              { tools_attributes: %i[id name price _destroy] }
            ]
          )
        end
      end
    end
  end
end
