# frozen_string_literal: true

class WebflowService
  include HTTParty

  base_uri "https://api.webflow.com/v2"

  # Rate limiting: 60 requests per minute
  RATE_LIMIT_PER_MINUTE = 60

  def initialize
    @api_key = Rails.application.credentials.webflow_token
    @rate_limit_requests = []
  end

  # Sites
  def list_sites
    make_request(:get, "/sites")
  end

  def get_site(site_id)
    make_request(:get, "/sites/#{site_id}")
  end

  # Collections
  def list_collections(site_id)
    make_request(:get, "/sites/#{site_id}/collections")
  end

  def get_collection(site_id, collection_id)
    make_request(:get, "/sites/#{site_id}/collections/#{collection_id}")
  end

  def create_collection(site_id, collection_data)
    make_request(:post, "/sites/#{site_id}/collections", body: collection_data)
  end

  def update_collection(site_id, collection_id, collection_data)
    make_request(:patch, "/sites/#{site_id}/collections/#{collection_id}", body: collection_data)
  end

  def delete_collection(site_id, collection_id)
    make_request(:delete, "/sites/#{site_id}/collections/#{collection_id}")
  end

  # Collection Items
  def list_items(site_id, collection_id, params = {})
    query_params = build_query_params(params)
    make_request(:get, "/sites/#{site_id}/collections/#{collection_id}/items#{query_params}")
  end

  def get_item(site_id, collection_id, item_id)
    make_request(:get, "/sites/#{site_id}/collections/#{collection_id}/items/#{item_id}")
  end

  def create_item(site_id, collection_id, item_data)
    make_request(:post, "/sites/#{site_id}/collections/#{collection_id}/items", body: item_data)
  end

  def update_item(site_id, collection_id, item_id, item_data)
    make_request(:patch, "/sites/#{site_id}/collections/#{collection_id}/items/#{item_id}", body: item_data)
  end

  def delete_item(site_id, collection_id, item_id)
    make_request(:delete, "/sites/#{site_id}/collections/#{collection_id}/items/#{item_id}")
  end

  def publish_items(site_id, collection_id, item_ids)
    make_request(:post, "/sites/#{site_id}/collections/#{collection_id}/items/publish",
                 body: { itemIds: item_ids })
  end

  def unpublish_items(site_id, collection_id, item_ids)
    make_request(:post, "/sites/#{site_id}/collections/#{collection_id}/items/unpublish",
                 body: { itemIds: item_ids })
  end

  # Forms
  def list_forms(site_id)
    make_request(:get, "/sites/#{site_id}/forms")
  end

  def get_form(site_id, form_id)
    make_request(:get, "/sites/#{site_id}/forms/#{form_id}")
  end

  def create_form_submission(site_id, form_id, submission_data)
    make_request(:post, "/sites/#{site_id}/forms/#{form_id}/submissions", body: submission_data)
  end

  # Assets
  def list_assets(site_id, params = {})
    query_params = build_query_params(params)
    make_request(:get, "/sites/#{site_id}/assets#{query_params}")
  end

  def get_asset(site_id, asset_id)
    make_request(:get, "/sites/#{site_id}/assets/#{asset_id}")
  end

  def create_asset(site_id, asset_data)
    make_request(:post, "/sites/#{site_id}/assets", body: asset_data)
  end

  def update_asset(site_id, asset_id, asset_data)
    make_request(:patch, "/sites/#{site_id}/assets/#{asset_id}", body: asset_data)
  end

  def delete_asset(site_id, asset_id)
    make_request(:delete, "/sites/#{site_id}/assets/#{asset_id}")
  end

  # Users
  def list_users(site_id, params = {})
    query_params = build_query_params(params)
    make_request(:get, "/sites/#{site_id}/users#{query_params}")
  end

  def get_user(site_id, user_id)
    make_request(:get, "/sites/#{site_id}/users/#{user_id}")
  end

  def create_user(site_id, user_data)
    make_request(:post, "/sites/#{site_id}/users", body: user_data)
  end

  def update_user(site_id, user_id, user_data)
    make_request(:patch, "/sites/#{site_id}/users/#{user_id}", body: user_data)
  end

  def delete_user(site_id, user_id)
    make_request(:delete, "/sites/#{site_id}/users/#{user_id}")
  end

  # Comments
  def list_comments(site_id, params = {})
    query_params = build_query_params(params)
    make_request(:get, "/sites/#{site_id}/comments#{query_params}")
  end

  def get_comment(site_id, comment_id)
    make_request(:get, "/sites/#{site_id}/comments/#{comment_id}")
  end

  def create_comment(site_id, comment_data)
    make_request(:post, "/sites/#{site_id}/comments", body: comment_data)
  end

  def update_comment(site_id, comment_id, comment_data)
    make_request(:patch, "/sites/#{site_id}/comments/#{comment_id}", body: comment_data)
  end

  def delete_comment(site_id, comment_id)
    make_request(:delete, "/sites/#{site_id}/comments/#{comment_id}")
  end

  # Legacy method for backward compatibility
  def send_window_schedule_repair(window_schedule_repair)
    site_id = Rails.application.credentials.webflow_site_id
    collection_id = Rails.application.credentials.webflow_collection_id

    create_item(site_id, collection_id, window_schedule_repair_data(window_schedule_repair))
  end

  private

  def make_request(method, path, options = {})
    check_rate_limit

    response = self.class.send(
      method,
      path,
      options.merge(
        headers: headers,
        timeout: 30
      )
    )

    log_request(method, path, response)

    if response.success?
      response.parsed_response
    else
      handle_error_response(response)
    end
  end

  def headers
    {
      "Authorization" => "Bearer #{@api_key}",
      "accept-version" => "1.0.0",
      "Content-Type" => "application/json"
    }
  end

  def build_query_params(params)
    return "" if params.empty?

    query_string = params.map { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
    "?#{query_string}"
  end

  def check_rate_limit
    now = Time.current
    @rate_limit_requests.reject! { |time| time < now - 1.minute }

    if @rate_limit_requests.size >= RATE_LIMIT_PER_MINUTE
      sleep_time = 60 - (now - @rate_limit_requests.first).to_i
      Rails.logger.warn "Rate limit reached, sleeping for #{sleep_time} seconds"
      sleep(sleep_time) if sleep_time > 0
    end

    @rate_limit_requests << now
  end

  def log_request(method, path, response)
    Rails.logger.info "Webflow API #{method.upcase} #{path} - Status: #{response.code}"

    if response.code >= 400
      Rails.logger.error "Webflow API Error: #{response.body}"
    end
  end

  def handle_error_response(response)
    error_message = case response.code
                    when 400
                      "Bad Request - Invalid parameters"
                    when 401
                      "Unauthorized - Check your API token"
                    when 403
                      "Forbidden - Insufficient permissions"
                    when 404
                      "Not Found - Resource not found"
                    when 429
                      "Rate Limited - Too many requests"
                    when 500..599
                      "Server Error - Webflow API issue"
                    else
                      "HTTP #{response.code} - #{response.body}"
                    end

    raise WebflowApiError.new(error_message, response.code, response.body)
  end

  def window_schedule_repair_data(window_schedule_repair)
    {
      fieldData: {
        name: window_schedule_repair.name,
        slug: window_schedule_repair.slug,
        'reference-number': window_schedule_repair.reference_number,
        address: window_schedule_repair.address,
        'flat-number': window_schedule_repair.flat_number,
        details: window_schedule_repair.details,
        'total-vat-included-price': window_schedule_repair.total_vat_included_price,
        'total-vat-excluded-price': window_schedule_repair.total_vat_excluded_price,
        status: window_schedule_repair.status,
        'status-color': window_schedule_repair.status_color,
        'grand-total': window_schedule_repair.grand_total,
        images: window_schedule_repair.images.map { |img| Rails.application.routes.url_helpers.url_for(img) }
      },
      isArchived: false,
      isDraft: false
    }
  end
end

# Custom error class for Webflow API errors
class WebflowApiError < StandardError
  attr_reader :status_code, :response_body

  def initialize(message, status_code = nil, response_body = nil)
    super(message)
    @status_code = status_code
    @response_body = response_body
  end
end
