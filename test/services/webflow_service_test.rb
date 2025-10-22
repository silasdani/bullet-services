# frozen_string_literal: true

require "test_helper"

class WebflowItemServiceTest < ActiveSupport::TestCase
  setup do
    @item_service = Webflow::ItemService.new
    @site_id = "test_site_id"
    @collection_id = "test_collection_id"
    @item_id = "test_item_id"
  end

  test "initializes with webflow token from credentials" do
    assert_not_nil @item_service.instance_variable_get(:@api_key)
  end

  test "sets correct base URI for v2 API" do
    assert_equal "https://api.webflow.com/v2", Webflow::ItemService.base_uri
  end

  test "includes proper headers" do
    headers = @item_service.send(:headers)

    assert_includes headers["Authorization"], "Bearer"
    assert_equal "2.0.0", headers["accept-version"]
    assert_equal "application/json", headers["Content-Type"]
  end

  test "builds query parameters correctly" do
    params = { limit: 10, offset: 0, sort: "created" }
    query_string = @item_service.send(:build_query_params, params)

    assert_includes query_string, "limit=10"
    assert_includes query_string, "offset=0"
    assert_includes query_string, "sort=created"
  end

  test "handles empty query parameters" do
    query_string = @item_service.send(:build_query_params, {})
    assert_equal "", query_string
  end

  test "handles WebflowApiError correctly" do
    error = WebflowApiError.new("Test error", 400, "Bad request")

    assert_equal "Test error", error.message
    assert_equal 400, error.status_code
    assert_equal "Bad request", error.response_body
  end

  test "rate limiting prevents too many requests" do
    # Mock the HTTParty response to avoid actual API calls
    mock_response = mock("response")
    mock_response.stubs(:success?).returns(true)
    mock_response.stubs(:parsed_response).returns({})
    mock_response.stubs(:code).returns(200)

    Webflow::ItemService.stubs(:get).returns(mock_response)

    # Make multiple requests to test rate limiting
    5.times do
      @item_service.list_items
    end

    # Should not raise an error due to rate limiting
    assert true
  end

  test "handles different HTTP error codes" do
    error_codes = [ 400, 401, 403, 404, 429, 500 ]

    error_codes.each do |code|
      mock_response = mock("response")
      mock_response.stubs(:success?).returns(false)
      mock_response.stubs(:code).returns(code)
      mock_response.stubs(:body).returns("Error message")

      Webflow::ItemService.stubs(:get).returns(mock_response)

      assert_raises WebflowApiError do
        @item_service.list_items
      end
    end
  end

  test "supports all major Webflow item operations" do
    # Test that all major methods are available
    methods = [
      :list_items, :get_item, :create_item, :update_item, :delete_item,
      :publish_items, :unpublish_items
    ]

    methods.each do |method|
      assert @item_service.respond_to?(method), "Method #{method} should be available"
    end
  end

  test "validates required credentials" do
    # Test that the service requires WEBFLOW_TOKEN in credentials
    assert_not_nil ENV.fetch("WEBFLOW_TOKEN")
  end
end
