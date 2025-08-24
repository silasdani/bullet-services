class Api::V1::WindowScheduleRepairsController < Api::V1::BaseController
  before_action :set_window_schedule_repair, only: [:show, :update, :destroy, :send_to_webflow]

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

    service = WebflowService.new
    service.send_window_schedule_repair(@window_schedule_repair)

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
