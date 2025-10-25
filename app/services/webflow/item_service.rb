# frozen_string_literal: true

module Webflow
  # Service for managing Webflow collection items
  class ItemService < BaseService
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
      make_request(:post, "/collections/#{@collection_id}/items/publish",
                   body: { itemIds: item_ids })
    end

    def unpublish_items(item_ids)
      make_request(:delete, "/collections/#{@collection_id}/items/live",
                   body: { items: item_ids.map { |id| { id: id } } })
    end
  end
end
