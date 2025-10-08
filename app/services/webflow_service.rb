# frozen_string_literal: true

class WebflowService
  include HTTParty

  base_uri "https://api.webflow.com/v2"

  # Rate limiting: 60 requests per minute
  RATE_LIMIT_PER_MINUTE = 60

  def initialize
    @api_key = ENV.fetch("WEBFLOW_TOKEN")
    @site_id = ENV.fetch("WEBFLOW_SITE_ID")
    @collection_id = ENV.fetch("WEBFLOW_WRS_COLLECTION_ID")
    @rate_limit_requests = []
  end

  # Collections
  def list_collections
    make_request(:get, "/sites/#{@site_id}/collections")
  end

  def get_collection
    make_request(:get, "/sites/#{@site_id}/collections/#{@collection_id}")
  end

  # Collection Items
  def list_items(params = {})
    query_params = build_query_params(params)
    make_request(:get, "/sites/#{@site_id}/collections/#{@collection_id}/items/live#{query_params}")
  end

  def get_item(item_id)
    make_request(:get, "/sites/#{@site_id}/collections/#{@collection_id}/items/#{item_id}")
  end

  def create_item(item_data)
    make_request(:post, "/sites/#{@site_id}/collections/#{@collection_id}/items", body: item_data)
  end

  def update_item(item_id, item_data)
    make_request(:patch, "/sites/#{@site_id}/collections/#{@collection_id}/items/#{item_id}", body: item_data)
  end

  def delete_item(item_id)
    make_request(:delete, "/sites/#{@site_id}/collections/#{@collection_id}/items/#{item_id}")
  end

  def publish_items(item_ids)
    make_request(:post, "/sites/#{@site_id}/collections/#{@collection_id}/items/publish",
                 body: { itemIds: item_ids })
  end

  def unpublish_items(item_ids)
    make_request(:post, "/sites/#{@site_id}/collections/#{@collection_id}/items/unpublish",
                 body: { itemIds: item_ids })
  end

  # Legacy method for backward compatibility
  def send_window_schedule_repair(window_schedule_repair)
    create_item(window_schedule_repair_data(window_schedule_repair))
  end

  private

  def make_request(method, path, options = {})
    check_rate_limit

    request_options = options.dup

    if request_options[:body].is_a?(Hash)
      request_options[:body] = request_options[:body].to_json
    end

    # Log the request body if present (log JSON string when available)
    if request_options[:body]
      log_request_body(method, path, request_options[:body])
    end

    response = self.class.send(
      method,
      path,
      request_options.merge(
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
      "accept-version" => "2.0.0",
      "Content-Type" => "application/json"
    }
  end

  def build_query_params(params)
    return "" if params.empty?

    query_string = params.to_h.entries.map { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
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

  def log_request_body(method, path, body)
    Rails.logger.info "Webflow API #{method.upcase} #{path} - Request Body: #{body.is_a?(String) ? body : body.inspect}"
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
    # Use the instance method from the WRS concern for better encapsulation
    window_schedule_repair.to_webflow_formatted
  end
end
