# frozen_string_literal: true

class Api::V1::QuotationsController < Api::V1::BaseController
  before_action :set_quotation, only: [:show, :update, :destroy, :send_to_webflow]

  def index
    @quotations = policy_scope(Quotation)
                    .includes([images_attachments: :blob])
                    .order(created_at: :desc)

    render json: @quotations
  end

  def show
    authorize @quotation
    render json: @quotation
  end

  def create
    @quotation = current_user.quotations.build(quotation_params)
    authorize @quotation

    if @quotation.save
      attach_images if params[:images].present?
      render json: @quotation, status: :created
    else
      render json: { errors: @quotation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @quotation
    if @quotation.update(quotation_params)
      attach_images if params[:images].present?
      render json: @quotation
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
end