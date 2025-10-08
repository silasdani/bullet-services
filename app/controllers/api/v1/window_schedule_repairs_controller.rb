class Api::V1::WindowScheduleRepairsController < Api::V1::BaseController
  before_action :set_window_schedule_repair, only: [ :show, :update, :destroy, :send_to_webflow, :restore, :publish_to_webflow, :unpublish_from_webflow ]

  def index
    @q = policy_scope(WindowScheduleRepair).includes(:user, :windows, windows: [ :tools, :image_attachment ]).ransack(params[:q])
    @window_schedule_repairs = @q.result.page(params[:page]).per(params[:per_page] || 100)

    render json: {
      data: @window_schedule_repairs.map { |wrs| WindowScheduleRepairSerializer.new(wrs).as_json },
      meta: {
        current_page: @window_schedule_repairs.current_page,
        total_pages: @window_schedule_repairs.total_pages,
        total_count: @window_schedule_repairs.total_count,
        per_page: @window_schedule_repairs.limit_value,
        has_next_page: @window_schedule_repairs.next_page.present?,
        has_prev_page: @window_schedule_repairs.prev_page.present?
      }
    }
  end

  def show
    authorize @window_schedule_repair
    render json: WindowScheduleRepairSerializer.new(@window_schedule_repair).as_json
  end

  def create
    authorize WindowScheduleRepair

    service = WrsCreationService.new(current_user, window_schedule_repair_params)
    result = service.create

    if result[:success]
      render json: {
        success: true,
        message: "WRS created successfully",
        id: service.wrs.id,
        name: service.wrs.name,
        address: service.wrs.address
      }, status: :created
    else
      render json: { errors: result[:errors] }, status: :unprocessable_content
    end
  end

  def update
    authorize @window_schedule_repair

    service = WrsCreationService.new(current_user, window_schedule_repair_params)
    result = service.update(@window_schedule_repair.id)

    if result[:success]
      @window_schedule_repair.reload
      render json: @window_schedule_repair
    else
      render json: { errors: result[:errors] }, status: :unprocessable_content
    end
  end

  def destroy
    authorize @window_schedule_repair
    @window_schedule_repair.soft_delete!
    render json: {
      success: true,
      message: "WRS deleted successfully",
      deleted_at: @window_schedule_repair.deleted_at
    }
  end

  def restore
    authorize @window_schedule_repair
    @window_schedule_repair.restore!
    render json: {
      success: true,
      message: "WRS restored successfully",
      data: WindowScheduleRepairSerializer.new(@window_schedule_repair).as_json
    }
  end

  def send_to_webflow
    authorize @window_schedule_repair, :send_to_webflow?

    service = WebflowService.new
    service.send_window_schedule_repair(@window_schedule_repair)

    render json: { message: "Sent to Webflow successfully" }
  end

  def publish_to_webflow
    authorize @window_schedule_repair, :publish_to_webflow?

    begin
      service = WebflowService.new

      # First ensure the item exists in Webflow (create as draft if needed)
      unless @window_schedule_repair.webflow_item_id.present?
        response = service.send_window_schedule_repair(@window_schedule_repair)
        @window_schedule_repair.update!(webflow_item_id: response["id"])
      end

      # Publish the item
      service.publish_items([ @window_schedule_repair.webflow_item_id ])

      # Update local status
      @window_schedule_repair.mark_as_published!

      render json: {
        success: true,
        message: "WRS published to Webflow successfully",
        webflow_item_id: @window_schedule_repair.webflow_item_id,
        last_published: @window_schedule_repair.last_published
      }
    rescue WebflowApiError => e
      render json: {
        success: false,
        error: "Failed to publish to Webflow: #{e.message}",
        status_code: e.status_code
      }, status: :unprocessable_entity
    rescue => e
      render json: {
        success: false,
        error: "Unexpected error: #{e.message}"
      }, status: :internal_server_error
    end
  end

  def unpublish_from_webflow
    authorize @window_schedule_repair, :unpublish_from_webflow?

    begin
      unless @window_schedule_repair.webflow_item_id.present?
        render json: {
          success: false,
          error: "WRS not found in Webflow"
        }, status: :not_found
        return
      end

      service = WebflowService.new
      service.unpublish_items([ @window_schedule_repair.webflow_item_id ])

      # Update local status
      @window_schedule_repair.mark_as_draft!

      render json: {
        success: true,
        message: "WRS unpublished from Webflow successfully",
        webflow_item_id: @window_schedule_repair.webflow_item_id
      }
    rescue WebflowApiError => e
      render json: {
        success: false,
        error: "Failed to unpublish from Webflow: #{e.message}",
        status_code: e.status_code
      }, status: :unprocessable_entity
    rescue => e
      render json: {
        success: false,
        error: "Unexpected error: #{e.message}"
      }, status: :internal_server_error
    end
  end

  private

  def set_window_schedule_repair
    # For restore action, we need to find deleted records too
    if action_name == "restore"
      @window_schedule_repair = WindowScheduleRepair.with_deleted.includes(:user, :windows, windows: [ :tools, :image_attachment ]).find(params[:id])
    else
      @window_schedule_repair = WindowScheduleRepair.includes(:user, :windows, windows: [ :tools, :image_attachment ]).find(params[:id])
    end
  end

  def window_schedule_repair_params
    # Handle both JSON and FormData
    if request.content_type&.include?("multipart/form-data")
      # FormData parameters
      params.permit(
        :name, :slug, :webflow_collection_id, :webflow_item_id, :reference_number,
        :address, :flat_number, :details,
        :total_vat_excluded_price, :status, :status_color, :grand_total,
        images: [],
        windows_attributes: [
          :id, :location, :image, :_destroy,
          tools_attributes: [ :id, :name, :price, :_destroy ]
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
          tools_attributes: [ :id, :name, :price, :_destroy ]
        ]
      )
    end
  end
end
