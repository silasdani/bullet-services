# frozen_string_literal: true

module Webflow
  # Service for building Webflow item data
  class ItemBuilderService < ApplicationService
    attribute :field_data, default: -> { {} }

    def call
      build_item_data
    end

    private

    def build_item_data
      {
        fieldData: build_field_data_hash,
        isArchived: false,
        isDraft: true
      }
    end

    def build_field_data_hash
      {
        'name' => field_data['name'],
        'slug' => field_data['slug'],
        'reference-number' => field_data['reference-number'] || '',
        'project-summary' => field_data['project-summary'] || field_data['address'] || '',
        'flat-number' => field_data['flat-number'] || '',
        'window-location' => field_data['window-location'] || '',
        'window-1-items-2' => field_data['window-1-items-2'] || '',
        'window-1-items-prices-3' => field_data['window-1-items-prices-3'] || '',
        'window-2-location' => field_data['window-2-location'] || '',
        'window-2-items-2' => field_data['window-2-items-2'] || '',
        'window-2-items-prices-3' => field_data['window-2-items-prices-3'] || '',
        'window-3-location' => field_data['window-3-location'] || '',
        'window-3-items' => field_data['window-3-items'] || '',
        'window-3-items-prices' => field_data['window-3-items-prices'] || '',
        'window-4-location' => field_data['window-4-location'] || '',
        'window-4-items' => field_data['window-4-items'] || '',
        'window-4-items-prices' => field_data['window-4-items-prices'] || '',
        'window-5-location' => field_data['window-5-location'] || '',
        'window-5-items' => field_data['window-5-items'] || '',
        'window-5-items-prices' => field_data['window-5-items-prices'] || '',
        'total-incl-vat' => field_data['total-incl-vat'] || 0,
        'total-exc-vat' => field_data['total-exc-vat'] || 0,
        'grand-total' => field_data['grand-total'] || 0,
        'accepted-declined' => field_data['accepted-declined'] || '#000000',
        'accepted-decline' => field_data['accepted-decline'] || ''
      }
    end
  end
end
