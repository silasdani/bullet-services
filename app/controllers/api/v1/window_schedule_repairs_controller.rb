class Api::V1::WindowScheduleRepairsController < Api::V1::BaseController
  before_action :set_window_schedule_repair, only: [:show, :update, :destroy]

  def index
    @window_schedule_repairs = policy_scope(WindowScheduleRepair).includes(:user, :windows, windows: [:tools, :image_attachment])
    render json: @window_schedule_repairs
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
    @window_schedule_repair.destroy
    head :no_content
  end

  def send_to_webflow
    authorize @window_schedule_repair
    # TODO: Implement Webflow integration logic

    #             "slug": "reference-number",
    #             "slug": "project-summary",
    #             "slug": "flat-number",
    #             "slug": "main-project-image",
    #             "slug": "window-location",
    #             "slug": "window-1-items-2",
    #             "slug": "window-1-items-prices-3",
    #             "slug": "window-2-location",
    #             "slug": "window-2",
    #             "slug": "window-2-items-2",
    #             "slug": "window-2-items-prices-3",
    #             "slug": "window-3-location",
    #             "slug": "window-3-image",
    #             "slug": "window-3-items",
    #             "slug": "window-3-items-prices",
    #             "slug": "total-incl-vat",
    #             "type": "Number",
    #             "slug": "total-exc-vat",
    #             "slug": "window-4-location",
    #             "slug": "window-4-image",
    #             "slug": "window-4-items",
    #             "slug": "window-4-items-prices",
    #             "slug": "window-5-location",
    #             "slug": "window-5-image",
    #             "slug": "window-5-items",
    #             "slug": "window-5-items-prices",
    #             "slug": "accepted-declined",
    #             "slug": "grand-total",
    #             "slug": "accepted-decline",
    #             "slug": "name",
    #             "slug": "slug",

    render json: { message: "Sent to Webflow successfully" }
  end

  private

  def set_window_schedule_repair
    @window_schedule_repair = WindowScheduleRepair.includes(:user, :windows, windows: [:tools, :image_attachment]).find(params[:id])
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
          tools_attributes: [:id, :name, :price, :_destroy]
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
          tools_attributes: [:id, :name, :price, :_destroy]
        ]
      )
    end
  end
end
