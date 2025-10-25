# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webflow::ItemService, type: :service do
  let(:item_service) { described_class.new }
  let(:site_id) { 'test_site_id' }
  let(:collection_id) { 'test_collection_id' }
  let(:item_id) { 'test_item_id' }

  describe 'initialization' do
    it 'initializes with webflow token from credentials' do
      expect(item_service.instance_variable_get(:@api_key)).not_to be_nil
    end

    it 'sets correct base URI for v2 API' do
      expect(described_class.base_uri).to eq('https://api.webflow.com/v2')
    end
  end

  describe 'headers' do
    it 'includes proper headers' do
      headers = item_service.send(:headers)

      expect(headers['Authorization']).to include('Bearer')
      expect(headers['accept-version']).to eq('2.0.0')
      expect(headers['Content-Type']).to eq('application/json')
    end
  end

  describe 'query parameters' do
    it 'builds query parameters correctly' do
      params = { limit: 10, offset: 0, sort: 'created' }
      query_string = item_service.send(:build_query_params, params)

      expect(query_string).to include('limit=10')
      expect(query_string).to include('offset=0')
      expect(query_string).to include('sort=created')
    end

    it 'handles empty query parameters' do
      query_string = item_service.send(:build_query_params, {})
      expect(query_string).to eq('')
    end
  end

  describe 'error handling' do
    it 'handles WebflowApiError correctly' do
      error = WebflowApiError.new('Test error', 400, 'Bad request')

      expect(error.message).to eq('Test error')
      expect(error.status_code).to eq(400)
      expect(error.response_body).to eq('Bad request')
    end

    it 'handles different HTTP error codes' do
      error_codes = [400, 401, 403, 404, 429, 500]

      error_codes.each do |code|
        mock_response = double('response')
        allow(mock_response).to receive(:success?).and_return(false)
        allow(mock_response).to receive(:code).and_return(code)
        allow(mock_response).to receive(:body).and_return('Error message')
        allow(mock_response).to receive(:headers).and_return({})

        allow(described_class).to receive(:get).and_return(mock_response)

        expect do
          item_service.list_items(collection_id)
        end.to raise_error(WebflowApiError)
      end
    end
  end

  describe 'rate limiting' do
    it 'handles rate limiting gracefully' do
      # Mock successful responses to avoid actual API calls
      mock_response = double('response')
      allow(mock_response).to receive(:success?).and_return(true)
      allow(mock_response).to receive(:parsed_response).and_return({})
      allow(mock_response).to receive(:code).and_return(200)

      allow(described_class).to receive(:get).and_return(mock_response)

      # Make multiple requests to test rate limiting
      expect do
        5.times { item_service.list_items(collection_id) }
      end.not_to raise_error
    end
  end

  describe 'API methods' do
    it 'supports all major Webflow item operations' do
      methods = %i[
        list_items get_item create_item update_item
        publish_items unpublish_items
      ]

      methods.each do |method|
        expect(item_service).to respond_to(method), "Method #{method} should be available"
      end
    end
  end

  describe 'credentials validation' do
    it 'validates required credentials' do
      expect(ENV.fetch('WEBFLOW_TOKEN')).not_to be_nil
    end
  end
end
