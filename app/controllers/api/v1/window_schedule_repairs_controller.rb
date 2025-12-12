# frozen_string_literal: true

module Api
  module V1
    class WindowScheduleRepairsController < Api::V1::BaseController
      include WebflowPublishing

      before_action :set_window_schedule_repair,
                    only: %i[show update restore publish_to_webflow unpublish_from_webflow send_to_webflow]

      def index
        authorize WindowScheduleRepair

        paginated_collection = build_wrs_collection.page(@page).per(@per_page)
        serialized_data = serialize_wrs_collection(paginated_collection)

        render_success(
          data: serialized_data,
          meta: pagination_meta(paginated_collection)
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
            message: 'WRS created successfully',
            status: :created
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
        window_schedule_repair = WindowScheduleRepair.find_by(id: params[:id])

        if window_schedule_repair.nil?
          render_error(message: 'WRS not found', status: :not_found)
          return
        end

        authorize window_schedule_repair

        window_schedule_repair.update(deleted_at: Time.current)

        render_success(
          data: {},
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

      def build_wrs_collection
        collection = policy_scope(WindowScheduleRepair)
                     .includes(:user, :building, :windows, windows: %i[tools image_attachment])
        collection = collection.ransack(params[:q]).result if params[:q].present?
        collection
      end

      def serialize_wrs_collection(collection)
        collection.map do |wrs|
          WindowScheduleRepairSerializer.new(wrs).serializable_hash
        end
      end

      def set_window_schedule_repair
        # For restore action, we need to find deleted records too
        if action_name == 'restore'
          @window_schedule_repair = WindowScheduleRepair.with_deleted
                                                        .includes(:user, :building, :windows,
                                                                  windows: %i[tools image_attachment])
                                                        .find(params[:id])
        else
          @window_schedule_repair = WindowScheduleRepair.includes(:user, :building, :windows,
                                                                  windows: %i[tools image_attachment])
                                                        .find(params[:id])
        end
      end

      def window_schedule_repair_params
        if request.content_type&.include?('multipart/form-data')
          params.permit(*wrs_permitted_params)
        else
          params.require(:window_schedule_repair).permit(*wrs_permitted_params)
        end
      end

      def wrs_permitted_params
        [
          :name, :slug, :webflow_item_id, :reference_number,
          :building_id, :flat_number, :details,
          :total_vat_excluded_price, :status, :status_color, :grand_total,
          { images: [],
            windows_attributes: [
              :id, :location, :image, :_destroy,
              { tools_attributes: %i[id name price _destroy] }
            ] }
        ]
      end
    end
  end
end
