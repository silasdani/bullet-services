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
        **build_basic_fields,
        **build_window_fields,
        **build_financial_fields,
        **build_status_fields
      }
    end

    def build_basic_fields
      {
        'name' => field_data['name'],
        'slug' => field_data['slug'],
        'reference-number' => field_data['reference-number'] || '',
        'project-summary' => field_data['project-summary'] || field_data['address'] || '',
        'flat-number' => field_data['flat-number'] || ''
      }
    end

    def build_window_fields
      fields = { 'window-location' => field_data['window-location'] || '' }
      (1..5).each do |num|
        fields.merge!(build_window_fields_for_number(num))
      end
      fields
    end

    def build_window_fields_for_number(num)
      if num == 1
        {
          'window-1-items-2' => field_data['window-1-items-2'] || '',
          'window-1-items-prices-3' => field_data['window-1-items-prices-3'] || ''
        }
      else
        {
          "window-#{num}-location" => field_data["window-#{num}-location"] || '',
          "window-#{num}-items" => field_data["window-#{num}-items"] || '',
          "window-#{num}-items-prices" => field_data["window-#{num}-items-prices"] || ''
        }
      end
    end

    def build_financial_fields
      {
        'total-incl-vat' => field_data['total-incl-vat'] || 0,
        'total-exc-vat' => field_data['total-exc-vat'] || 0,
        'grand-total' => field_data['grand-total'] || 0
      }
    end

    def build_status_fields
      {
        'accepted-declined' => field_data['accepted-declined'] || '#000000',
        'accepted-decline' => field_data['accepted-decline'] || ''
      }
    end
  end
end
