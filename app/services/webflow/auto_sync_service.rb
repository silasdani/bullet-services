# frozen_string_literal: true

module Webflow
  # Service for handling automatic synchronization of WRS to Webflow
  class AutoSyncService < ApplicationService
    attribute :wrs

    def call
      return failure_result("record_deleted") if wrs.deleted?
      return failure_result("not_draft") unless should_auto_sync?
      return failure_result("invalid_data") unless valid_for_sync?

      with_error_handling do
        if wrs.webflow_item_id.present?
          update_webflow_item
        else
          create_webflow_item
        end
      end
    end

    private

    def should_auto_sync?
      # Only auto-sync if:
      # 1. The record is marked as draft (is_draft = true), OR
      # 2. The record has no webflow_item_id (never been synced)
      wrs.is_draft? || wrs.webflow_item_id.blank?
    end

    def valid_for_sync?
      wrs.name.present? && wrs.address.present? && wrs.slug.present?
    end

    def create_webflow_item
      log_image_status

      item_data = wrs.to_webflow_formatted.merge(isDraft: true)
      response = item_service.create_item(item_data)

      wrs.update_column(:webflow_item_id, response["id"])

      log_info("Created WRS ##{wrs.id} in Webflow as draft (#{response['id']})")

      success_result("created", response["id"])
    end

    def update_webflow_item
      unless wrs.is_draft?
        log_info("Skipping WRS ##{wrs.id} - item is published")
        return failure_result("item_published")
      end

      log_image_status

      item_data = wrs.to_webflow_formatted.merge(isDraft: true)
      item_service.update_item(wrs.webflow_item_id, item_data)

      log_info("Updated WRS ##{wrs.id} in Webflow (#{wrs.webflow_item_id})")

      success_result("updated", wrs.webflow_item_id)
    end

    def log_image_status
      wrs.windows.each_with_index do |window, index|
        if window.image.attached?
          log_info("Window #{index + 1} has image attached (#{window.image.filename})")
        else
          log_info("Window #{index + 1} has NO image")
        end
      end
    end

    def item_service
      @item_service ||= ItemService.new
    end

    def success_result(action, webflow_item_id)
      { success: true, action: action, webflow_item_id: webflow_item_id }
    end

    def failure_result(reason)
      { success: false, reason: reason }
    end
  end
end
