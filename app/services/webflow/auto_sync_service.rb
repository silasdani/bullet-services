# frozen_string_literal: true

module Webflow
  # Service for handling automatic synchronization of WRS to Webflow
  class AutoSyncService < ApplicationService
    attribute :wrs

    def call
      return failure_result('record_deleted') if wrs.deleted?
      return failure_result('not_draft') unless should_auto_sync?
      return failure_result('invalid_data') unless valid_for_sync?

      sync_to_webflow
    rescue WebflowApiError => e
      handle_webflow_error(e)
    rescue StandardError => e
      handle_unexpected_sync_error(e)
    end

    def sync_to_webflow
      if wrs.webflow_item_id.present?
        update_webflow_item
      else
        create_webflow_item
      end
    end

    def handle_webflow_error(error)
      {
        success: false,
        error: error.message,
        status_code: error.status_code
      }
    end

    def handle_unexpected_sync_error(error)
      log_error("Unexpected error: #{error.message}")
      add_error(error.message)
      {
        success: false,
        error: error.message
      }
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
      item_data = build_draft_item_data
      response = item_service.create_item(wrs.webflow_collection_id, item_data)
      update_webflow_item_id(response['id'])
      log_creation_success(response['id'])
      success_result('created', response['id'])
    end

    def build_draft_item_data
      wrs.to_webflow_formatted.merge(isDraft: true)
    end

    def update_webflow_item_id(webflow_id)
      wrs.update_column(:webflow_item_id, webflow_id)
    end

    def log_creation_success(webflow_id)
      log_info("Created WRS ##{wrs.id} in Webflow as draft (#{webflow_id})")
    end

    def update_webflow_item
      return handle_published_item if wrs.published?

      log_image_status
      item_data = build_draft_item_data
      item_service.update_item(wrs.webflow_collection_id, wrs.webflow_item_id, item_data)
      log_update_success
      success_result('updated', wrs.webflow_item_id)
    end

    def handle_published_item
      log_info("Skipping WRS ##{wrs.id} - item is published")
      failure_result('item_published')
    end

    def log_update_success
      log_info("Updated WRS ##{wrs.id} in Webflow (#{wrs.webflow_item_id})")
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
      @item_service ||= Webflow::ItemService.new
    end

    def success_result(action, webflow_item_id)
      { success: true, action: action, webflow_item_id: webflow_item_id }
    end

    def failure_result(reason)
      { success: false, reason: reason }
    end
  end
end
