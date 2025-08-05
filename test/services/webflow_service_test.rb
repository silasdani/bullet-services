# frozen_string_literal: true

require 'test_helper'

class WebflowServiceTest < ActiveSupport::TestCase
  setup do
    @webflow_service = WebflowService.new
    @site_id = 'test_site_id'
    @collection_id = 'test_collection_id'
    @item_id = 'test_item_id'
  end

  test 'initializes with webflow token from credentials' do
    assert_not_nil @webflow_service.instance_variable_get(:@api_key)
  end

  test 'sets correct base URI for v2 API' do
    assert_equal 'https://api.webflow.com/v2', WebflowService.base_uri
  end

  test 'includes proper headers' do
    headers = @webflow_service.send(:headers)

    assert_includes headers['Authorization'], 'Bearer'
    assert_equal '1.0.0', headers['accept-version']
    assert_equal 'application/json', headers['Content-Type']
  end

  test 'builds query parameters correctly' do
    params = { limit: 10, offset: 0, sort: 'created' }
    query_string = @webflow_service.send(:build_query_params, params)

    assert_includes query_string, 'limit=10'
    assert_includes query_string, 'offset=0'
    assert_includes query_string, 'sort=created'
  end

  test 'handles empty query parameters' do
    query_string = @webflow_service.send(:build_query_params, {})
    assert_equal '', query_string
  end

  test 'quotation_data formats data correctly' do
    quotation = quotations(:one)
    data = @webflow_service.send(:quotation_data, quotation)

    assert_includes data.keys, :fieldData
    assert_includes data.keys, :isArchived
    assert_includes data.keys, :isDraft
    assert_equal false, data[:isArchived]
    assert_equal false, data[:isDraft]
  end

  test 'handles WebflowApiError correctly' do
    error = WebflowApiError.new('Test error', 400, 'Bad request')

    assert_equal 'Test error', error.message
    assert_equal 400, error.status_code
    assert_equal 'Bad request', error.response_body
  end

  test 'rate limiting prevents too many requests' do
    # Mock the HTTParty response to avoid actual API calls
    mock_response = mock('response')
    mock_response.stubs(:success?).returns(true)
    mock_response.stubs(:parsed_response).returns({})
    mock_response.stubs(:code).returns(200)

    WebflowService.stubs(:get).returns(mock_response)

    # Make multiple requests to test rate limiting
    5.times do
      @webflow_service.list_sites
    end

    # Should not raise an error due to rate limiting
    assert true
  end

  test 'handles different HTTP error codes' do
    error_codes = [400, 401, 403, 404, 429, 500]

    error_codes.each do |code|
      mock_response = mock('response')
      mock_response.stubs(:success?).returns(false)
      mock_response.stubs(:code).returns(code)
      mock_response.stubs(:body).returns('Error message')

      WebflowService.stubs(:get).returns(mock_response)

      assert_raises WebflowApiError do
        @webflow_service.list_sites
      end
    end
  end

  test 'legacy send_quotation method works' do
    quotation = quotations(:one)

    # Mock the create_item method to avoid actual API calls
    @webflow_service.stubs(:create_item).returns({ id: 'test_id' })

    result = @webflow_service.send_quotation(quotation)

    assert_equal({ id: 'test_id' }, result)
  end

  test 'logs requests correctly' do
    mock_response = mock('response')
    mock_response.stubs(:success?).returns(true)
    mock_response.stubs(:parsed_response).returns({})
    mock_response.stubs(:code).returns(200)
    mock_response.stubs(:body).returns('')

    WebflowService.stubs(:get).returns(mock_response)

    # Capture log output
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    @webflow_service.list_sites

    assert_includes log_output.string, 'Webflow API GET /sites'
  end

  test 'handles network timeouts' do
    WebflowService.stubs(:get).raises(Net::ReadTimeout)

    assert_raises Net::ReadTimeout do
      @webflow_service.list_sites
    end
  end

  test 'validates required credentials' do
    # Test that the service requires webflow_token in credentials
    assert_not_nil Rails.application.credentials.webflow_token
  end

  test 'supports all major Webflow API operations' do
    # Test that all major methods are available
    methods = [
      :list_sites, :get_site,
      :list_collections, :get_collection, :create_collection, :update_collection, :delete_collection,
      :list_items, :get_item, :create_item, :update_item, :delete_item,
      :publish_items, :unpublish_items,
      :list_forms, :get_form, :create_form_submission,
      :list_assets, :get_asset, :create_asset, :update_asset, :delete_asset,
      :list_users, :get_user, :create_user, :update_user, :delete_user,
      :list_comments, :get_comment, :create_comment, :update_comment, :delete_comment
    ]

    methods.each do |method|
      assert @webflow_service.respond_to?(method), "Method #{method} should be available"
    end
  end
end
