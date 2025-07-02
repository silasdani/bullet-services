# frozen_string_literal: true

class Api::V1::QuotationsController < Api::V1::BaseController
  before_action :set_quotation, only: [:show, :update, :destroy, :send_to_webflow]

  def index
    @quotations = policy_scope(Quotation)
                    .includes([images_attachments: :blob])
                    .order(created_at: :desc)

    render json: quotations_json(@quotations)
  end

  def show
    authorize @quotation
    render json: quotation_json(@quotation)
  end

  def create
    @quotation = current_user.quotations.build(quotation_params)
    authorize @quotation

    if @quotation.save
      attach_images if params[:images].present?
      render json: quotation_json(@quotation), status: :created
    else
      render json: { errors: @quotation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @quotation
    if @quotation.update(quotation_params)
      attach_images if params[:images].present?
      render json: quotation_json(@quotation)
    else
      render json: { errors: @quotation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @quotation
    @quotation.destroy
    head :no_content
  end

  def send_to_webflow
    authorize @quotation, :send_to_webflow?
    WebflowService.new(@quotation).send_quotation
    render json: { message: 'Quotation sent to Webflow successfully' }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_quotation
    @quotation = policy_scope(Quotation).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Quotation not found' }, status: :not_found
  end

  def quotation_params
    params.require(:quotation).permit(:address, :details, :price, :status,
                                      :client_name, :client_phone, :client_email)
  end

  def attach_images
    params[:images].each do |image|
      @quotation.images.attach(image)
    end
  end

  def quotations_json(quotations)
    quotations.map { |q| quotation_json(q) }
  end

  def quotation_json(quotation)
    {
      id: quotation.id,
      address: quotation.address,
      details: quotation.details,
      price: quotation.price,
      status: quotation.status,
      client_name: quotation.client_name,
      client_phone: quotation.client_phone,
      client_email: quotation.client_email,
      created_at: quotation.created_at,
      updated_at: quotation.updated_at,
      images: quotation.images.map do |image|
        {
          id: image.id,
          url: url_for(image),
          filename: image.filename
        }
      end,
      user: {
        id: quotation.user.id,
        email: quotation.user.email,
        role: quotation.user.role
      }
    }
  end
end