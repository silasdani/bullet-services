# frozen_string_literal: true

module Wrs
  extend ActiveSupport::Concern

  # Returns raw field data for Webflow
  def to_webflow
    {
      **build_basic_webflow_fields,
      **build_window_webflow_fields,
      **build_pricing_webflow_fields,
      **build_status_webflow_fields
    }.compact
  end

  def build_basic_webflow_fields
    {
      'reference-number' => reference_number,
      'project-summary' => address,
      'flat-number' => flat_number,
      'main-project-image' => window_image_url(1),
      'name' => name,
      'slug' => slug
    }
  end

  def build_window_webflow_fields
    fields = {
      'window-location' => window_location(1),
      'window-1-items-2' => window_items_list(1),
      'window-1-items-prices-3' => window_items_prices_list(1)
    }

    (2..5).each do |num|
      fields.merge!(build_window_fields_for_number(num))
    end

    fields
  end

  def build_window_fields_for_number(num)
    {
      "window-#{num}" => window_image_url(num),
      "window-#{num}-location" => window_location(num),
      "window-#{num}-items" => window_items_list(num),
      "window-#{num}-items-prices" => window_items_prices_list(num)
    }
  end

  def build_pricing_webflow_fields
    {
      'total-incl-vat' => total_vat_included_price,
      'total-exc-vat' => total_vat_excluded_price,
      'grand-total' => grand_total
    }
  end

  def build_status_webflow_fields
    {
      'accepted-declined' => status_color,
      'accepted-decline' => status
    }
  end

  # Returns formatted data structure compatible with existing WebflowCollectionMapperService
  # Respects the current draft/published status of the record
  def to_webflow_formatted
    {
      fieldData: to_webflow,
      isArchived: is_archived || false,
      isDraft: is_draft.nil? || is_draft # Default to draft if not set
    }
  end

  private

  def window_location(window_number)
    window = windows.order(:created_at)[window_number - 1]
    window&.location
  end

  def window_image_url(window_number)
    window = windows.order(:created_at)[window_number - 1]
    return nil unless window

    # Prefer ActiveStorage attached image, fallback to Webflow image URL
    if window.image.present?
      window.image.url
    else
      window.webflow_image_url
    end
  end

  def window_items_list(window_number)
    window = windows.order(:created_at)[window_number - 1]
    return nil unless window

    window.tools.map(&:name).join("\n")
  end

  def window_items_prices_list(window_number)
    window = windows.order(:created_at)[window_number - 1]
    return nil unless window

    window.tools.map(&:price).join("\n")
  end
end
