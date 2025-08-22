class Api::V1::ImagesController < Api::V1::BaseController
  before_action :set_window, only: [:upload_window_image]

  def upload_window_image
    authorize @window, :update?

    service = WindowImageUploadService.new(@window)
    result = service.upload_image(params[:image])

    if result[:success]
      render json: result
    else
      render json: { error: result[:errors].join(', ') }, status: :unprocessable_entity
    end
  end

  def upload_multiple_images
    @window_schedule_repair = WindowScheduleRepair.find(params[:window_schedule_repair_id])
    authorize @window_schedule_repair, :update?

    if params[:images].blank?
      render json: { error: 'No images provided' }, status: :unprocessable_entity
      return
    end

    begin
      # Remove existing images
      @window_schedule_repair.images.purge if @window_schedule_repair.images.attached?

      # Attach new images
      params[:images].each_with_index do |image, index|
        @window_schedule_repair.images.attach(image)
      end

      # Send to Webflow if collection info exists
      if @window_schedule_repair.webflow_collection_id.present?
        send_to_webflow_async(@window_schedule_repair)
      end

      render json: {
        success: true,
        message: 'Images uploaded successfully',
        image_count: @window_schedule_repair.images.count,
        image_urls: @window_schedule_repair.images.map { |img| url_for(img) }
      }
    rescue => e
      Rails.logger.error "Multiple images upload error: #{e.message}"
      render json: { error: 'Failed to upload images' }, status: :internal_server_error
    end
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
