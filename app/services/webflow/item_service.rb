# frozen_string_literal: true

module Webflow
  class ItemService < BaseService
    def list_items(collection_id, params = {})
      query_params = build_query_params(params)
      make_request(
        :get,
        "/sites/#{@site_id}/collections/#{collection_id}/items/live#{query_params}"
      )
    end

    def get_item(collection_id, item_id)
      make_request(
        :get,
        "/sites/#{@site_id}/collections/#{collection_id}/items/#{item_id}"
      )
    end

    def create_item(collection_id, item_data)
      make_request(
        :post,
        "/sites/#{@site_id}/collections/#{collection_id}/items",
        body: item_data.to_json
      )
    end

    def update_item(collection_id, item_id, item_data)
      make_request(
        :patch,
        "/sites/#{@site_id}/collections/#{collection_id}/items/#{item_id}",
        body: item_data.to_json
      )
    end

    def publish_items(collection_id, item_ids)
      make_request(
        :post,
        "/collections/#{collection_id}/items/publish",
        body: { itemIds: item_ids }.to_json
      )
    end

    def unpublish_items(collection_id, item_ids)
      make_request(
        :delete,
        "/collections/#{collection_id}/items/live",
        body: { items: item_ids.map { |id| { id: id } } }.to_json
      )
    end

    private

    def build_query_params(params)
      return '' if params.empty?

      '?' + params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
    end
  end
end
