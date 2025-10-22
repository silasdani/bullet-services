# frozen_string_literal: true

module Wrs
  # Service for syncing WRS data from Webflow
  class SyncService < BaseService
    attribute :admin_user, default: -> { nil }

    def initialize(attributes = {})
      super
      @total_synced = 0
      @total_skipped = 0
      @processed_count = 0
    end

    def call(wrs_data)
      sync_single(wrs_data)
    end

    def sync_single(wrs_data)
      process_wrs_item(wrs_data)
    end

    def sync_batch(wrs_items)
      total_items = wrs_items.size
      log_info("Starting sync of #{total_items} WRS items...")

      wrs_items.each_with_index do |wrs_data, index|
        process_wrs_item(wrs_data)
        @processed_count += 1
        render_progress(@processed_count, total_items)
      end

      log_info("Sync complete! Synced: #{@total_synced}, Skipped: #{@total_skipped}")
      { synced: @total_synced, skipped: @total_skipped }
    end

    private

    def process_wrs_item(wrs_data)
      begin
        return skip_item("missing_required_fields") unless valid_wrs_data?(wrs_data)

        wrs = find_or_initialize_wrs(wrs_data)
        set_sync_flags(wrs)

        update_wrs_from_webflow(wrs, wrs_data)
        wrs.save!

        recreate_windows_and_tools(wrs, wrs_data)
        sync_back_to_webflow(wrs)

        @total_synced += 1
        success_result(wrs)
      rescue => e
        @total_skipped += 1
        log_error("Error processing WRS item #{wrs_data['id']}: #{e.class} - #{e.message}")
        failure_result(e.message)
      end
    end

    def valid_wrs_data?(wrs_data)
      field_data = wrs_data["fieldData"]
      field_data["project-summary"].present? && field_data["name"].present?
    end

    def find_or_initialize_wrs(wrs_data)
      wrs = WindowScheduleRepair.find_or_initialize_by(webflow_item_id: wrs_data["id"])
      wrs.user = admin_user if wrs.new_record? && admin_user
      wrs
    end

    def set_sync_flags(wrs)
      wrs.skip_webflow_sync = true
      wrs.skip_auto_sync = true
    end

    def update_wrs_from_webflow(wrs, wrs_data)
      field_data = wrs_data["fieldData"]
      status_color = field_data["accepted-declined"]

      wrs.assign_attributes(
        name: field_data["name"] || "WRS #{wrs_data['id']}",
        address: field_data["project-summary"],
        flat_number: field_data["flat-number"],
        details: field_data["project-summary"],
        reference_number: extract_reference_number(field_data),
        total_vat_included_price: extract_price(field_data, "total-incl-vat"),
        total_vat_excluded_price: extract_price(field_data, "total-exc-vat"),
        grand_total: extract_price(field_data, "grand-total"),
        status: map_status_color_to_status(status_color),
        status_color: status_color,
        slug: field_data["slug"] || "wrs-#{wrs_data['id']}",
        last_published: wrs_data["lastPublished"],
        is_draft: wrs_data["isDraft"],
        is_archived: wrs_data["isArchived"],
        webflow_main_image_url: extract_main_image_url(field_data)
      )

      apply_webflow_timestamps(wrs, wrs_data)
    end

    def recreate_windows_and_tools(wrs, wrs_data)
      # Bulk delete existing tools and windows
      Tool.joins(:window).where(windows: { window_schedule_repair_id: wrs.id }).delete_all
      wrs.windows.delete_all

      window_data = prepare_window_data(wrs_data["fieldData"], wrs_data)
      create_windows_and_tools_bulk(wrs, window_data)
    end

    def sync_back_to_webflow(wrs)
      return unless wrs.webflow_item_id.present?

      begin
        wrs.reload
        log_tools_info(wrs)
        calculate_and_save_totals(wrs)

        item_service = Webflow::ItemService.new
        item_data = wrs.to_webflow_formatted.merge(isDraft: wrs.is_draft?)
        item_service.update_item(wrs.webflow_item_id, item_data)

        log_info("Synced recalculated totals back to Webflow for WRS ##{wrs.id}")
      rescue => e
        log_error("Error syncing back to Webflow for WRS ##{wrs.id}: #{e.message}")
      end
    end

    def log_tools_info(wrs)
      log_info("Recalculating totals for WRS ##{wrs.id}")
      wrs.windows.each_with_index do |window, idx|
        log_info("  Window #{idx + 1} (#{window.location}): #{window.tools.count} tools")
        window.tools.each do |tool|
          log_info("    - #{tool.name}: #{tool.price}")
        end
      end
    end

    def extract_reference_number(field_data)
      wf_first(field_data, "reference-number", "reference_number", "referenceNumber")
    end

    def extract_price(field_data, key)
      wf_first(field_data, key, key.gsub("-", "_"), key.camelize).to_f || 0.0
    end

    def extract_main_image_url(field_data)
      main_image = field_data["main-project-image"]
      main_image && main_image["url"]
    end

    def apply_webflow_timestamps(wrs, wrs_data)
      wrs.created_at = Time.parse(wrs_data["createdOn"]) rescue wrs.created_at
      wrs.updated_at = Time.parse(wrs_data["lastUpdated"]) rescue wrs.updated_at
    end

    def prepare_window_data(field_data, wrs_data)
      windows = []

      (1..10).each do |idx|
        location_key = idx == 1 ? "window-location" : "window-#{idx}-location"
        location = field_data[location_key]

        next if location.blank? || location.to_s.strip.empty?

        items_val = extract_items(field_data, idx)
        next if items_val.blank? || items_val.to_s.strip.empty?

        prices_val = extract_prices(field_data, idx)
        image_url = extract_image_url(field_data, idx)

        windows << {
          location: location,
          items: items_val,
          prices: prices_val,
          image_url: image_url,
          created_on: wrs_data["createdOn"],
          last_updated: wrs_data["lastUpdated"]
        }
      end

      windows
    end

    def extract_items(field_data, idx)
      items_keys = if idx == 1
        [ "window-1-items-2", "window-1-items", "window-items" ]
      else
        [ "window-#{idx}-items-2", "window-#{idx}-items" ]
      end
      wf_first(field_data, *items_keys)
    end

    def extract_prices(field_data, idx)
      prices_keys = if idx == 1
        [ "window-1-items-prices-3", "window-1-items-prices", "window-items-prices" ]
      else
        [ "window-#{idx}-items-prices-3", "window-#{idx}-items-prices" ]
      end
      wf_first(field_data, *prices_keys)
    end

    def extract_image_url(field_data, idx)
      if idx == 1
        main_image = field_data["main-project-image"]
        return main_image["url"] if main_image.is_a?(Hash)
        return main_image if main_image.is_a?(String)
      else
        image_val = field_data["window-#{idx}-image"] || field_data["window-#{idx}-image-url"]
        return image_val["url"] if image_val.is_a?(Hash)
        return image_val if image_val.is_a?(String)
      end
      nil
    end

    def create_windows_and_tools_bulk(wrs, window_data)
      return { windows_created: 0, tools_created: 0, mismatched_rows: 0 } if window_data.empty?

      # Bulk create windows
      windows_to_create = window_data.map do |window_info|
        {
          window_schedule_repair_id: wrs.id,
          location: window_info[:location],
          webflow_image_url: window_info[:image_url],
          created_at: (Time.parse(window_info[:created_on]) rescue Time.current),
          updated_at: (Time.parse(window_info[:last_updated]) rescue Time.current)
        }
      end

      Window.insert_all(windows_to_create, returning: [ :id, :location ])

      created_windows = Window.where(window_schedule_repair_id: wrs.id)
                             .where(location: window_data.map { |w| w[:location] })
                             .index_by(&:location)

      # Bulk create tools
      tools_to_create = []
      mismatches = 0

      window_data.each do |window_info|
        window = created_windows[window_info[:location]]
        next unless window

        items = parse_items(window_info[:items])
        prices = parse_prices(window_info[:prices])

        if items.length != prices.length && !prices.empty?
          mismatches += (items.length - prices.length).abs
        end

        prices = normalize_prices(items, prices)

        items.each_with_index do |item_name, index|
          price = prices[index] || 0
          tools_to_create << {
            window_id: window.id,
            name: item_name,
            price: price,
            created_at: (Time.parse(window_info[:created_on]) rescue Time.current),
            updated_at: (Time.parse(window_info[:last_updated]) rescue Time.current)
          }
        end
      end

      Tool.insert_all(tools_to_create) if tools_to_create.any?

      { windows_created: created_windows.size, tools_created: tools_to_create.size, mismatched_rows: mismatches }
    end

    def normalize_prices(items, prices)
      if prices.length < items.length
        prices + Array.new(items.length - prices.length, 0)
      elsif prices.length > items.length
        prices.first(items.length)
      else
        prices
      end
    end

    def parse_items(items_string)
      return [] if items_string.blank?
      items_string.to_s.split("\n").map(&:strip).reject(&:blank?)
    end

    def parse_prices(prices_string)
      return [] if prices_string.blank?
      prices_string.to_s.split("\n").map(&:strip).reject(&:blank?).map(&:to_i)
    end

    def wf_first(field_data, *keys)
      keys.each do |k|
        v = field_data[k]
        return v if v.present?
      end
      nil
    end

    def map_status_color_to_status(status_color)
      case status_color&.downcase
      when "#024900" # Green - accepted
        "approved"
      when "#750002", "#740000" # Dark colors - rejected
        "rejected"
      else
        "pending"
      end
    end

    def render_progress(processed, total)
      width = 40
      ratio = [ [ processed.to_f / [ total, 1 ].max, 0 ].max, 1 ].min
      filled = (ratio * width).floor
      bar = "[" + ("#" * filled) + ("-" * (width - filled)) + "]"
      percent = (ratio * 100).round(1)
      print "\r#{bar} #{percent}% (#{processed}/#{total})"
      $stdout.flush
    end

    def skip_item(reason)
      @total_skipped += 1
      { success: false, reason: reason }
    end

    def success_result(wrs)
      { success: true, wrs_id: wrs.id }
    end

    def failure_result(error_message)
      { success: false, error: error_message }
    end
  end
end
