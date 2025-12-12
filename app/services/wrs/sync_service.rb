# frozen_string_literal: true

module Wrs
  # Service for syncing WRS data from Webflow
  class SyncService < BaseService
    attribute :admin_user, default: -> {}

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

      wrs_items.each_with_index do |wrs_data, _index|
        process_wrs_item(wrs_data)
        @processed_count += 1
        render_progress(@processed_count, total_items)
      end

      log_info("Sync complete! Synced: #{@total_synced}, Skipped: #{@total_skipped}")
      { synced: @total_synced, skipped: @total_skipped }
    end

    private

    def process_wrs_item(wrs_data)
      return skip_item('missing_required_fields') unless valid_wrs_data?(wrs_data)

      wrs = find_or_initialize_wrs(wrs_data)
      apply_sync_flags(wrs)

      update_wrs_from_webflow(wrs, wrs_data)
      wrs.save!

      recreate_windows_and_tools(wrs, wrs_data)
      sync_back_to_webflow(wrs)

      @total_synced += 1
      success_result(wrs)
    rescue StandardError => e
      @total_skipped += 1
      log_error("Error processing WRS item #{wrs_data['id']}: #{e.class} - #{e.message}")
      failure_result(e.message)
    end

    def valid_wrs_data?(wrs_data)
      field_data = wrs_data['fieldData']
      field_data['project-summary'].present? && field_data['name'].present?
    end

    def find_or_initialize_wrs(wrs_data)
      wrs = WindowScheduleRepair.find_or_initialize_by(webflow_item_id: wrs_data['id'])
      wrs.user = admin_user if wrs.new_record? && admin_user
      wrs
    end

    def apply_sync_flags(wrs)
      wrs.skip_webflow_sync = true
      wrs.skip_auto_sync = true
    end

    def update_wrs_from_webflow(wrs, wrs_data)
      field_data = wrs_data['fieldData']
      wrs.assign_attributes(build_wrs_attributes(field_data, wrs_data))
      apply_webflow_timestamps(wrs, wrs_data)
    end

    def build_wrs_attributes(field_data, wrs_data)
      AttributeBuilder.build_wrs_attributes(field_data, wrs_data)
    end

    def recreate_windows_and_tools(wrs, wrs_data)
      # Bulk delete existing tools and windows
      Tool.joins(:window).where(windows: { window_schedule_repair_id: wrs.id }).delete_all
      wrs.windows.delete_all

      window_data = WebflowDataExtractor.prepare_window_data(wrs_data['fieldData'], wrs_data)
      WindowToolBuilder.create_windows_and_tools_bulk(wrs, window_data)
    end

    def sync_back_to_webflow(wrs)
      return unless wrs.webflow_item_id.present?

      begin
        prepare_wrs_for_sync(wrs)
        update_webflow_item(wrs)
        log_info("Synced recalculated totals back to Webflow for WRS ##{wrs.id}")
      rescue StandardError => e
        log_error("Error syncing back to Webflow for WRS ##{wrs.id}: #{e.message}")
      end
    end

    def prepare_wrs_for_sync(wrs)
      wrs.reload
      log_tools_info(wrs)
      wrs.calculate_totals
      wrs.save!
    end

    def update_webflow_item(wrs)
      item_service = Webflow::ItemService.new
      item_data = wrs.to_webflow_formatted.merge(isDraft: wrs.is_draft?)
      item_service.update_item(wrs.webflow_item_id, item_data)
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

    def apply_webflow_timestamps(wrs, wrs_data)
      wrs.created_at = begin
        Time.parse(wrs_data['createdOn'])
      rescue StandardError
        wrs.created_at
      end
      wrs.updated_at = begin
        Time.parse(wrs_data['lastUpdated'])
      rescue StandardError
        wrs.updated_at
      end
    end

    def render_progress(processed, total)
      width = 40
      ratio = (processed.to_f / [total, 1].max).clamp(0, 1)
      filled = (ratio * width).floor
      bar = "[#{'#' * filled}#{'-' * (width - filled)}]"
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
