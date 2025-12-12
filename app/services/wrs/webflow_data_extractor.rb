# frozen_string_literal: true

module Wrs
  class WebflowDataExtractor
    def self.prepare_window_data(field_data, wrs_data)
      windows = []
      (1..10).each do |idx|
        window_info = build_window_info(field_data, wrs_data, idx)
        windows << window_info if window_info
      end
      windows
    end

    def self.build_window_info(field_data, wrs_data, idx)
      location = extract_window_location(field_data, idx)
      return nil if location.blank? || location.to_s.strip.empty?

      items_val = extract_items(field_data, idx)
      return nil if items_val.blank? || items_val.to_s.strip.empty?

      {
        location: location,
        items: items_val,
        prices: extract_prices(field_data, idx),
        image_url: extract_image_url(field_data, idx),
        created_on: wrs_data['createdOn'],
        last_updated: wrs_data['lastUpdated']
      }
    end

    def self.extract_window_location(field_data, idx)
      location_key = idx == 1 ? 'window-location' : "window-#{idx}-location"
      field_data[location_key]
    end

    def self.extract_items(field_data, idx)
      items_keys = if idx == 1
                     ['window-1-items-2', 'window-1-items', 'window-items']
                   else
                     ["window-#{idx}-items-2", "window-#{idx}-items"]
                   end
      wf_first(field_data, *items_keys)
    end

    def self.extract_prices(field_data, idx)
      prices_keys = if idx == 1
                      ['window-1-items-prices-3', 'window-1-items-prices', 'window-items-prices']
                    else
                      ["window-#{idx}-items-prices-3", "window-#{idx}-items-prices"]
                    end
      wf_first(field_data, *prices_keys)
    end

    def self.extract_image_url(field_data, idx)
      if idx == 1
        main_image = field_data['main-project-image']
        return main_image['url'] if main_image.is_a?(Hash)
        return main_image if main_image.is_a?(String)
      else
        image_val = field_data["window-#{idx}-image"] || field_data["window-#{idx}-image-url"]
        return image_val['url'] if image_val.is_a?(Hash)
        return image_val if image_val.is_a?(String)
      end
      nil
    end

    def self.wf_first(field_data, *keys)
      keys.each do |k|
        v = field_data[k]
        return v if v.present?
      end
      nil
    end
  end
end
