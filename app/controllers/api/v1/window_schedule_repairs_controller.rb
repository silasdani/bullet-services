# frozen_string_literal: true

module Api
  module V1
    class WindowScheduleRepairsController < Api::V1::BaseController
      before_action :set_window_schedule_repair, only: %i[show update restore publish_to_webflow unpublish_from_webflow send_to_webflow]

      def index
        authorize WindowScheduleRepair

        # Start with policy scoped collection
        wrs_collection = policy_scope(WindowScheduleRepair)
                         .includes(:user, :windows, windows: %i[tools image_attachment])

        # Apply Ransack filtering if params[:q] is present
        if params[:q].present?
          wrs_collection = wrs_collection.ransack(params[:q]).result
        end

        # Apply pagination
        paginated_collection = wrs_collection.page(@page).per(@per_page)

        # Serialize the results
        serialized_data = paginated_collection.map do |wrs|
          WindowScheduleRepairSerializer.new(wrs).serializable_hash
        end

        # Return paginated response with meta
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

      def publish_to_webflow
        authorize @window_schedule_repair, :publish_to_webflow?

        unless @window_schedule_repair.webflow_item_id.present?
          render_error(
            message: 'WRS has not been synced to Webflow yet',
            status: :unprocessable_entity
          )
          return
        end

        begin
          item_service = Webflow::ItemService.new
          item_service.publish_items(
            @window_schedule_repair.webflow_collection_id,
            [@window_schedule_repair.webflow_item_id]
          )

          # Update the record to mark as published
          @window_schedule_repair.mark_as_published!
          @window_schedule_repair.reload

          render_success(
            data: WindowScheduleRepairSerializer.new(@window_schedule_repair).serializable_hash,
            message: 'WRS published to Webflow successfully'
          )
        rescue StandardError => e
          Rails.logger.error "Error publishing to Webflow: #{e.message}"
          render_error(
            message: 'Failed to publish to Webflow',
            details: e.message,
            status: :internal_server_error
          )
        end
      end

      def unpublish_from_webflow
        authorize @window_schedule_repair, :unpublish_from_webflow?

        unless @window_schedule_repair.webflow_item_id.present?
          render_error(
            message: 'WRS has not been synced to Webflow yet',
            status: :unprocessable_entity
          )
          return
        end

        begin
          item_service = Webflow::ItemService.new
          item_service.unpublish_items(
            @window_schedule_repair.webflow_collection_id,
            [@window_schedule_repair.webflow_item_id]
          )

          # Update the record to mark as draft
          @window_schedule_repair.mark_as_draft!
          @window_schedule_repair.reload

          render_success(
            data: WindowScheduleRepairSerializer.new(@window_schedule_repair).serializable_hash,
            message: 'WRS unpublished from Webflow successfully'
          )
        rescue StandardError => e
          Rails.logger.error "Error unpublishing from Webflow: #{e.message}"
          render_error(
            message: 'Failed to unpublish from Webflow',
            details: e.message,
            status: :internal_server_error
          )
        end
      end

      def send_to_webflow
        authorize @window_schedule_repair, :send_to_webflow?

        # This triggers the sync to Webflow
        begin
          service = Webflow::AutoSyncService.new(wrs: @window_schedule_repair)
          result = service.call

          if result[:success]
            @window_schedule_repair.reload
            render_success(
              data: WindowScheduleRepairSerializer.new(@window_schedule_repair).serializable_hash,
              message: 'WRS sent to Webflow successfully'
            )
          else
            render_error(
              message: 'Failed to send to Webflow',
              details: result[:reason] || result[:error]
            )
          end
        rescue StandardError => e
          Rails.logger.error "Error sending to Webflow: #{e.message}"
          render_error(
            message: 'Failed to send to Webflow',
            details: e.message,
            status: :internal_server_error
          )
        end
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
