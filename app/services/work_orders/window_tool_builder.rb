# frozen_string_literal: true

module WorkOrders
  class WindowToolBuilder
    def self.create_windows_and_tools_bulk(work_order, window_data)
      return { windows_created: 0, tools_created: 0, mismatched_rows: 0 } if window_data.empty?

      created_windows = create_windows_bulk(work_order, window_data)
      tools_result = create_tools_bulk(created_windows, window_data)

      {
        windows_created: created_windows.size,
        tools_created: tools_result[:tools_created],
        mismatched_rows: tools_result[:mismatches]
      }
    end

    def self.create_windows_bulk(work_order, window_data)
      windows_to_create = build_windows_data(work_order, window_data)
      Window.insert_all(windows_to_create, returning: %i[id location])

      Window.where(work_order_id: work_order.id)
            .where(location: window_data.map { |w| w[:location] })
            .index_by(&:location)
    end

    def self.build_windows_data(work_order, window_data)
      window_data.map do |window_info|
        {
          work_order_id: work_order.id,
          location: window_info[:location],
          created_at: parse_time_safe(window_info[:created_on]),
          updated_at: parse_time_safe(window_info[:last_updated])
        }
      end
    end

    def self.create_tools_bulk(created_windows, window_data)
      tools_to_create = []
      mismatches = 0

      window_data.each do |window_info|
        window = created_windows[window_info[:location]]
        next unless window

        result = build_tools_for_window(window, window_info)
        tools_to_create.concat(result[:tools])
        mismatches += result[:mismatches]
      end

      Tool.insert_all(tools_to_create) if tools_to_create.any?

      { tools_created: tools_to_create.size, mismatches: mismatches }
    end

    def self.build_tools_for_window(window, window_info)
      items = parse_items(window_info[:items])
      prices = parse_prices(window_info[:prices])
      mismatches = calculate_mismatches(items, prices)
      normalized_prices = normalize_prices(items, prices)

      tools = build_tools_array(window, items, normalized_prices, window_info)

      { tools: tools, mismatches: mismatches }
    end

    def self.calculate_mismatches(items, prices)
      return 0 if items.length == prices.length || prices.empty?

      (items.length - prices.length).abs
    end

    def self.build_tools_array(window, items, prices, window_info)
      items.each_with_index.map do |item_name, index|
        {
          window_id: window.id,
          name: item_name,
          price: prices[index] || 0,
          created_at: parse_time_safe(window_info[:created_on]),
          updated_at: parse_time_safe(window_info[:last_updated])
        }
      end
    end

    def self.normalize_prices(items, prices)
      if prices.length < items.length
        prices + Array.new(items.length - prices.length, 0)
      elsif prices.length > items.length
        prices.first(items.length)
      else
        prices
      end
    end

    def self.parse_items(items_string)
      return [] if items_string.blank?

      items_string.to_s.split("\n").map(&:strip).reject(&:blank?)
    end

    def self.parse_prices(prices_string)
      return [] if prices_string.blank?

      prices_string.to_s.split("\n").map(&:strip).reject(&:blank?).map(&:to_i)
    end

    def self.parse_time_safe(time_string)
      Time.parse(time_string)
    rescue StandardError
      Time.current
    end
  end
end
