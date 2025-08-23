module Wrs
  extend ActiveSupport::Concern

  # Returns raw field data for Webflow
  def to_webflow
    {
      # Basic WRS information
      "reference-number" => reference_number,
      "project-summary" => address,
      "flat-number" => flat_number,
      "main-project-image" => window_image_url(1),
      "name" => name,
      "slug" => slug,

      # Window 1
      "window-location" => window_location(1),
      "window-1-items-2" => window_items_list(1),
      "window-1-items-prices-3" => window_items_prices_list(1),

      # Window 2
      "window-2" => window_image_url(2),
      "window-2-location" => window_location(2),
      "window-2-items-2" => window_items_list(2),
      "window-2-items-prices-3" => window_items_prices_list(2),

      # Window 3
      "window-3-image" => window_image_url(3),
      "window-3-location" => window_location(3),
      "window-3-items" => window_items_list(3),
      "window-3-items-prices" => window_items_prices_list(3),

      # Window 4
      "window-4-image" => window_image_url(4),
      "window-4-location" => window_location(4),
      "window-4-items" => window_items_list(4),
      "window-4-items-prices" => window_items_prices_list(4),

      # Window 5
      "window-5-image" => window_image_url(5),
      "window-5-location" => window_location(5),
      "window-5-items" => window_items_list(5),
      "window-5-items-prices" => window_items_prices_list(5),

      # Pricing information
      "total-incl-vat" => total_vat_included_price,
      "total-exc-vat" => total_vat_excluded_price,
      "grand-total" => grand_total,

      # Status - use color values instead of text
      "accepted-declined" => status_color,
      "accepted-decline" => status
    }.compact
  end

  # Returns formatted data structure compatible with existing WebflowCollectionMapperService
  def to_webflow_formatted
    {
      fieldData: to_webflow,
      isArchived: false,
      isDraft: false
    }
  end

  private

  def window_location(window_number)
    window = windows.order(:created_at)[window_number - 1]
    window&.location
  end

  def window_image_url(window_number)
    window = windows.order(:created_at)[window_number - 1]
    return nil unless window&.image&.present?

    # Return the image URL for Webflow
    window.image_url
  end

  def window_items_list(window_number)
    window = windows.order(:created_at)[window_number - 1]
    return nil unless window

    window.tools.map(&:name).join('\n')
  end

  def window_items_prices_list(window_number)
    window = windows.order(:created_at)[window_number - 1]
    return nil unless window

    window.tools.map(&:price).join('\n')
  end
end
