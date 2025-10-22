# frozen_string_literal: true

module Webflow
  # Service for managing Webflow collections
  class CollectionService < BaseService
    def list_collections
      make_request(:get, "/sites/#{@site_id}/collections")
    end

    def get_collection
      make_request(:get, "/sites/#{@site_id}/collections/#{@collection_id}")
    end
  end
end
