# frozen_string_literal: true

module Api
  module V1
    class ImagesController < Api::V1::BaseController
      before_action :set_window, only: [:upload_window_image]

      def upload_window_image
        authorize @window, :update?

        service = WindowImageUploadService.new(@window)
        result = service.upload_image(params[:image])

        if result[:success]
          render json: result
        else
          render json: { error: result[:errors].join(', ') }, status: :unprocessable_content
        end
      end

      def upload_window_image_for_wrs
        @window_schedule_repair = find_window_schedule_repair
        authorize @window_schedule_repair, :update?

        return render_no_image_error if params[:image].blank?

        upload_image_via_temp_window
      rescue StandardError => e
        handle_upload_error(e)
      end

      def find_window_schedule_repair
        WindowScheduleRepair.find(params[:window_schedule_repair_id])
      end

      def render_no_image_error
        render json: { error: 'No image provided' }, status: :unprocessable_content
      end

      def upload_image_via_temp_window
        temp_window = @window_schedule_repair.windows.build(location: 'Temporary')
        service = WindowImageUploadService.new(temp_window)
        result = service.upload_image(params[:image])

        if result[:success]
          render json: result
        else
          render json: { error: result[:errors].join(', ') }, status: :unprocessable_content
        end
      end

      def handle_upload_error(error)
        Rails.logger.error "Window image upload for WRS error: #{error.message}"
        render json: { error: 'Failed to upload image' }, status: :internal_server_error
      end

      def upload_multiple_images
        @window_schedule_repair = find_window_schedule_repair
        authorize @window_schedule_repair, :update?

        return render_no_images_error if params[:images].blank?

        process_multiple_image_upload
      rescue StandardError => e
        handle_multiple_upload_error(e)
      end

      def render_no_images_error
        render json: { error: 'No images provided' }, status: :unprocessable_content
      end

      def process_multiple_image_upload
        purge_existing_images
        attach_new_images
        send_to_webflow_if_needed

        render json: build_upload_success_response
      end

      def purge_existing_images
        @window_schedule_repair.images.purge if @window_schedule_repair.images.attached?
      end

      def attach_new_images
        params[:images].each { |image| @window_schedule_repair.images.attach(image) }
      end

      def send_to_webflow_if_needed
        return unless @window_schedule_repair.webflow_collection_id.present?

        send_to_webflow_async(@window_schedule_repair)
      end

      def build_upload_success_response
        {
          success: true,
          message: 'Images uploaded successfully',
          image_count: @window_schedule_repair.images.count,
          image_urls: @window_schedule_repair.images.map { |img| url_for(img) }
        }
      end

      def handle_multiple_upload_error(error)
        Rails.logger.error "Multiple images upload error: #{error.message}"
        render json: { error: 'Failed to upload images' }, status: :internal_server_error
      end

      private

      def set_window
        @window = Window.find(params[:window_id])
      end

      def send_to_webflow_async(window_schedule_repair)
        # Send to Webflow asynchronously to avoid blocking the response
        WebflowUploadJob.perform_later(window_schedule_repair.id)
      end
    end
  end
end
