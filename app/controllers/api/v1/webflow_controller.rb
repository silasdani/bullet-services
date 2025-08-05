# frozen_string_literal: true

class Api::V1::WebflowController < Api::V1::BaseController
  before_action :set_webflow_service
  before_action :authorize_webflow_access

  # Sites
  def sites
    sites = @webflow_service.list_sites
    render json: sites
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def site
    site = @webflow_service.get_site(params[:site_id])
    render json: site
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  # Collections
  def collections
    collections = @webflow_service.list_collections(params[:site_id])
    render json: collections
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def collection
    collection = @webflow_service.get_collection(params[:site_id], params[:collection_id])
    render json: collection
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def create_collection
    collection = @webflow_service.create_collection(params[:site_id], collection_params)
    render json: collection, status: :created
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def update_collection
    collection = @webflow_service.update_collection(params[:site_id], params[:collection_id], collection_params)
    render json: collection
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def delete_collection
    @webflow_service.delete_collection(params[:site_id], params[:collection_id])
    head :no_content
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  # Collection Items
  def items
    items = @webflow_service.list_items(params[:site_id], params[:collection_id], items_params)
    render json: items
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def item
    item = @webflow_service.get_item(params[:site_id], params[:collection_id], params[:item_id])
    render json: item
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def create_item
    item = @webflow_service.create_item(params[:site_id], params[:collection_id], item_params)
    render json: item, status: :created
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def update_item
    item = @webflow_service.update_item(params[:site_id], params[:collection_id], params[:item_id], item_params)
    render json: item
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def delete_item
    @webflow_service.delete_item(params[:site_id], params[:collection_id], params[:item_id])
    head :no_content
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def publish_items
    result = @webflow_service.publish_items(params[:site_id], params[:collection_id], params[:item_ids])
    render json: result
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def unpublish_items
    result = @webflow_service.unpublish_items(params[:site_id], params[:collection_id], params[:item_ids])
    render json: result
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  # Forms
  def forms
    forms = @webflow_service.list_forms(params[:site_id])
    render json: forms
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def form
    form = @webflow_service.get_form(params[:site_id], params[:form_id])
    render json: form
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def create_form_submission
    submission = @webflow_service.create_form_submission(params[:site_id], params[:form_id], form_submission_params)
    render json: submission, status: :created
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  # Assets
  def assets
    assets = @webflow_service.list_assets(params[:site_id], assets_params)
    render json: assets
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def asset
    asset = @webflow_service.get_asset(params[:site_id], params[:asset_id])
    render json: asset
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def create_asset
    asset = @webflow_service.create_asset(params[:site_id], asset_params)
    render json: asset, status: :created
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def update_asset
    asset = @webflow_service.update_asset(params[:site_id], params[:asset_id], asset_params)
    render json: asset
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def delete_asset
    @webflow_service.delete_asset(params[:site_id], params[:asset_id])
    head :no_content
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  # Users
  def users
    users = @webflow_service.list_users(params[:site_id], users_params)
    render json: users
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def user
    user = @webflow_service.get_user(params[:site_id], params[:user_id])
    render json: user
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def create_user
    user = @webflow_service.create_user(params[:site_id], user_params)
    render json: user, status: :created
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def update_user
    user = @webflow_service.update_user(params[:site_id], params[:user_id], user_params)
    render json: user
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def delete_user
    @webflow_service.delete_user(params[:site_id], params[:user_id])
    head :no_content
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  # Comments
  def comments
    comments = @webflow_service.list_comments(params[:site_id], comments_params)
    render json: comments
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def comment
    comment = @webflow_service.get_comment(params[:site_id], params[:comment_id])
    render json: comment
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def create_comment
    comment = @webflow_service.create_comment(params[:site_id], comment_params)
    render json: comment, status: :created
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def update_comment
    comment = @webflow_service.update_comment(params[:site_id], params[:comment_id], comment_params)
    render json: comment
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  def delete_comment
    @webflow_service.delete_comment(params[:site_id], params[:comment_id])
    head :no_content
  rescue WebflowApiError => e
    render json: { error: e.message, status_code: e.status_code }, status: :unprocessable_entity
  end

  private

  def set_webflow_service
    @webflow_service = WebflowService.new
  end

  def authorize_webflow_access
    # Add authorization logic here if needed
    # For now, we'll assume any authenticated user can access Webflow API
    current_user&.webflow_access? || render(json: { error: 'Unauthorized' }, status: :unauthorized) unless current_user&.webflow_access?
  end

  def collection_params
    params.require(:collection).permit(:name, :slug, :singularName, :pluralName, :description)
  end

  def items_params
    params.permit(:limit, :offset, :sort, :filter)
  end

  def item_params
    params.require(:item).permit(:fieldData, :isArchived, :isDraft)
  end

  def form_submission_params
    params.require(:submission).permit(:data)
  end

  def assets_params
    params.permit(:limit, :offset, :sort, :filter)
  end

  def asset_params
    params.require(:asset).permit(:name, :url, :altText, :metadata)
  end

  def users_params
    params.permit(:limit, :offset, :sort, :filter)
  end

  def user_params
    params.require(:user).permit(:email, :firstName, :lastName, :metadata)
  end

  def comments_params
    params.permit(:limit, :offset, :sort, :filter)
  end

  def comment_params
    params.require(:comment).permit(:content, :author, :metadata)
  end
end
