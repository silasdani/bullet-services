class Api::V1::WindowScheduleRepairsController < Api::V1::BaseController
  before_action :set_window_schedule_repair, only: [:show, :update, :destroy]

  def index
    @window_schedule_repairs = policy_scope(WindowScheduleRepair)
    render json: @window_schedule_repairs
  end

  def show
    authorize @window_schedule_repair
    render json: @window_schedule_repair
  end

  def create
    @window_schedule_repair = current_user.window_schedule_repairs.build(window_schedule_repair_params)
    authorize @window_schedule_repair

    if @window_schedule_repair.save
      render json: @window_schedule_repair, status: :created
    else
      render json: { errors: @window_schedule_repair.errors }, status: :unprocessable_entity
    end
  end

  def update
    authorize @window_schedule_repair
    if @window_schedule_repair.update(window_schedule_repair_params)
      render json: @window_schedule_repair
    else
      render json: { errors: @window_schedule_repair.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @window_schedule_repair
    @window_schedule_repair.destroy
    head :no_content
  end

  private

  def set_window_schedule_repair
    @window_schedule_repair = WindowScheduleRepair.find(params[:id])
  end

  def window_schedule_repair_params
    params.require(:window_schedule_repair).permit(:name, :slug, :webflow_collection_id,
                                                  :webflow_item_id, :reference_number, :address,
                                                  :flat_number, :details, :total_vat_included_price,
                                                  :total_vat_excluded_price, :status, :status_color,
                                                  :grand_total, images: [])
  end
end
