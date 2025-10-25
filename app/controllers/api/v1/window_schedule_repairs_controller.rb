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

    service = Wrs::CreationService.new(user: current_user, params: window_schedule_repair_params)
    result = service.call

    if result[:success]
      render json: {
        success: true,
        message: "WRS created successfully",
        id: result[:wrs].id,
        name: result[:wrs].name,
        address: result[:wrs].address
      }, status: :created
    else
      render json: { errors: service.errors }, status: :unprocessable_content
    end
  end

  def update
    authorize @window_schedule_repair

    service = Wrs::CreationService.new(user: current_user, params: window_schedule_repair_params)
    result = service.update(@window_schedule_repair.id)

    if result[:success]
      @window_schedule_repair.reload
      render json: @window_schedule_repair
    else
      render json: { errors: service.errors }, status: :unprocessable_content
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

    item_service = Webflow::ItemService.new
    item_service.create_item(@window_schedule_repair.to_webflow_formatted)

    render json: { message: "Sent to Webflow successfully" }
  end

  def publish_to_webflow
    authorize @window_schedule_repair, :publish_to_webflow?

    begin
      item_service = Webflow::ItemService.new

      # First ensure the item exists in Webflow (create as draft if needed)
      unless @window_schedule_repair.webflow_item_id.present?
        response = item_service.create_item(@window_schedule_repair.to_webflow_formatted)
        @window_schedule_repair.update!(webflow_item_id: response["id"])
      end

      # Publish the item to live
      item_service.publish_items([ @window_schedule_repair.webflow_item_id ])

      # Sync back from Webflow to get the latest published state
      webflow_item = item_service.get_item(@window_schedule_repair.webflow_item_id)
      sync_service = Wrs::SyncService.new(admin_user: current_user)
      sync_result = sync_service.call(webflow_item)

      if sync_result[:success]
        @window_schedule_repair.reload
        render json: {
          success: true,
          message: "WRS published to Webflow and synced successfully",
          webflow_item_id: @window_schedule_repair.webflow_item_id,
          last_published: @window_schedule_repair.last_published,
          is_draft: @window_schedule_repair.is_draft
        }
      else
        render json: {
          success: true,
          message: "WRS published but sync failed",
          webflow_item_id: @window_schedule_repair.webflow_item_id,
          sync_error: sync_result[:error]
        }
      end
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

      item_service = Webflow::ItemService.new

      # Unpublish the item from live
      item_service.unpublish_items([ @window_schedule_repair.webflow_item_id ])

      # Update the draft version in Webflow with latest data (ensuring isDraft: true)
      draft_data = @window_schedule_repair.to_webflow_formatted.merge(isDraft: true)
      item_service.update_item(@window_schedule_repair.webflow_item_id, draft_data)

      # Sync back from Webflow to get the latest unpublished state
      webflow_item = item_service.get_item(@window_schedule_repair.webflow_item_id)
      sync_service = Wrs::SyncService.new(admin_user: current_user)
      sync_result = sync_service.call(webflow_item)

      if sync_result[:success]
        @window_schedule_repair.reload
        render json: {
          success: true,
          message: "WRS unpublished from Webflow and synced successfully",
          webflow_item_id: @window_schedule_repair.webflow_item_id,
          is_draft: @window_schedule_repair.is_draft
        }
      else
        render json: {
          success: true,
          message: "WRS unpublished but sync failed",
          webflow_item_id: @window_schedule_repair.webflow_item_id,
          sync_error: sync_result[:error]
        }
      end
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
