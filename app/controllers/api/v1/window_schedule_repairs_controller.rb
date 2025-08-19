class Api::V1::WindowScheduleRepairsController < Api::V1::BaseController
  before_action :set_window_schedule_repair, only: [:show, :update, :destroy]

  def index
    @window_schedule_repairs = policy_scope(WindowScheduleRepair)

    # Return raw JSON data to avoid serialization issues
    render json: @window_schedule_repairs.map do |wrs|
      {
        id: wrs.id,
        name: wrs.name,
        slug: wrs.slug,
        address: wrs.address,
        flat_number: wrs.flat_number,
        details: wrs.details,
        total_vat_included_price: wrs.total_vat_included_price,
        total_vat_excluded_price: wrs.total_vat_excluded_price,
        status: wrs.status,
        status_color: wrs.status_color,
        grand_total: wrs.grand_total,
        created_at: wrs.created_at,
        updated_at: wrs.updated_at,
        windows: wrs.windows.map do |window|
          {
            id: window.id,
            location: window.location,
            image: window.image.attached? ? {
              url: Rails.application.routes.url_helpers.rails_blob_url(window.image),
              filename: window.image.filename,
              content_type: window.image.content_type,
              byte_size: window.image.byte_size,
              attached: true
            } : nil,
            created_at: window.created_at,
            updated_at: window.updated_at,
            tools: window.tools.map do |tool|
              {
                id: tool.id,
                name: tool.name,
                price: tool.price,
                created_at: tool.created_at,
                updated_at: tool.updated_at
              }
            end
          }
        end
      }
    end
  end

  def show
    authorize @window_schedule_repair

    # Return raw JSON data to avoid serialization issues
    render json: {
      id: @window_schedule_repair.id,
      name: @window_schedule_repair.name,
      slug: @window_schedule_repair.slug,
      address: @window_schedule_repair.address,
      flat_number: @window_schedule_repair.flat_number,
      details: @window_schedule_repair.details,
      total_vat_included_price: @window_schedule_repair.total_vat_included_price,
      total_vat_excluded_price: @window_schedule_repair.total_vat_excluded_price,
      status: @window_schedule_repair.status,
      status_color: @window_schedule_repair.status_color,
      grand_total: @window_schedule_repair.grand_total,
      created_at: @window_schedule_repair.created_at,
      updated_at: @window_schedule_repair.updated_at,
      windows: @window_schedule_repair.windows.map do |window|
        {
          id: window.id,
          location: window.location,
          image: window.image.attached? ? {
            url: Rails.application.routes.url_helpers.rails_blob_url(window.image),
            filename: window.image.filename,
            content_type: window.image.content_type,
            byte_size: window.image.byte_size,
            attached: true
          } : nil,
          created_at: window.created_at,
          updated_at: window.updated_at,
          tools: window.tools.map do |tool|
            {
              id: tool.id,
              name: tool.name,
              price: tool.price,
              created_at: tool.created_at,
              updated_at: tool.updated_at
            }
          end
        }
      end
    }
  end

  def create
    @window_schedule_repair = current_user.window_schedule_repairs.build(window_schedule_repair_params)
    authorize @window_schedule_repair

    if @window_schedule_repair.save
      # Return minimal response to avoid serialization issues
      render json: {
        success: true,
        message: 'WRS created successfully',
        id: @window_schedule_repair.id,
        name: @window_schedule_repair.name,
        address: @window_schedule_repair.address
      }, status: :created
    else
      render json: { errors: @window_schedule_repair.errors }, status: :unprocessable_entity
    end
  end

  def update
    authorize @window_schedule_repair
    if @window_schedule_repair.update(window_schedule_repair_params)
      # Return raw JSON data to avoid serialization issues
      render json: {
        id: @window_schedule_repair.id,
        name: @window_schedule_repair.name,
        slug: @window_schedule_repair.slug,
        address: @window_schedule_repair.address,
        flat_number: @window_schedule_repair.flat_number,
        details: @window_schedule_repair.details,
        total_vat_included_price: @window_schedule_repair.total_vat_included_price,
        total_vat_excluded_price: @window_schedule_repair.total_vat_excluded_price,
        status: @window_schedule_repair.status,
        status_color: @window_schedule_repair.status_color,
        grand_total: @window_schedule_repair.grand_total,
        created_at: @window_schedule_repair.created_at,
        updated_at: @window_schedule_repair.updated_at,
        windows: @window_schedule_repair.windows.map do |window|
          {
            id: window.id,
            location: window.location,
            image: window.image.attached? ? {
              url: Rails.application.routes.url_helpers.rails_blob_url(window.image),
              filename: window.image.filename,
              content_type: window.image.content_type,
              byte_size: window.image.byte_size,
              attached: true
            } : nil,
            created_at: window.created_at,
            updated_at: window.updated_at,
            tools: window.tools.map do |tool|
              {
                id: tool.id,
                name: tool.name,
                price: tool.price,
                created_at: tool.created_at,
                updated_at: tool.updated_at
              }
            end
          }
        end
      }
    else
      render json: { errors: @window_schedule_repair.errors }, status: :unprocessable_entity
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
    render json: { message: 'Sent to Webflow successfully' }
  end

  private

  def set_window_schedule_repair
    @window_schedule_repair = WindowScheduleRepair.find(params[:id])
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
