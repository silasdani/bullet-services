# frozen_string_literal: true

class Api::V1::WebflowController < Api::V1::BaseController
  before_action :set_webflow_service
  before_action :authorize_webflow_access

  # Collections
  def collections
    collections = @webflow_service.list_collections(get_site_id)
    render json: collections
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_content
  end

  def collection
    collection = @webflow_service.get_collection(get_site_id, params[:collection_id])
    render json: collection
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_content
  end

  # Collection Items
  def items
    items = @webflow_service.list_items(get_site_id, params[:collection_id], items_params)
    render json: items
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_content
  end

  def item
    item = @webflow_service.get_item(get_site_id, params[:collection_id], params[:item_id])
    render json: item
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_content
  end

  def create_item
    form = WebflowItemForm.from_params(params)

    unless form.valid?
      render json: { errors: form.errors.full_messages }, status: :unprocessable_content
      return
    end

    item_data = WebflowItemBuilderService.new(form.to_webflow_format).build_item_data

    log_item_creation(item_data)

    item = @webflow_service.create_item(get_site_id, params[:collection_id], item_data)
    render json: item, status: :created
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_content
  end

  def update_item
    item = @webflow_service.update_item(get_site_id, params[:collection_id], params[:item_id], item_params)
    render json: item
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_content
  end

  def delete_item
    @webflow_service.delete_item(get_site_id, params[:collection_id], params[:item_id])
    head :no_content
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_content
  end

  def publish_items
    result = @webflow_service.publish_items(get_site_id, params[:collection_id], params[:item_ids])
    render json: result
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_content
  end

  def unpublish_items
    result = @webflow_service.unpublish_items(get_site_id, params[:collection_id], params[:item_ids])
    render json: result
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_content
  end

  private

  def set_webflow_service
    @webflow_service = WebflowService.new
  end

  def get_site_id
    params[:site_id] || Rails.application.credentials.webflow_site_id
  end

  def authorize_webflow_access
    if current_user.webflow_access == false
      render json: { error: "Webflow access is disabled" }, status: :unauthorized
    end
  end

  def items_params
    params.permit(:limit, :offset, :sort, :filter)
  end

  def log_item_creation(item_data)
    Rails.logger.info "Sending to Webflow API: #{item_data.inspect}"
    Rails.logger.info "JSON representation: #{item_data.to_json}"
  end
end
