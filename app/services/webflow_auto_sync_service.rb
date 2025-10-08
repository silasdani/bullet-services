# frozen_string_literal: true

# Service to handle automatic synchronization of WRS to Webflow
# Only syncs draft items to protect published content
class WebflowAutoSyncService
  def initialize(wrs)
    @wrs = wrs
    @webflow_service = WebflowService.new
  end

  def sync
    # Safety checks
    return { success: false, reason: "record_deleted" } if @wrs.deleted?
    return { success: false, reason: "not_draft" } unless should_auto_sync?
    return { success: false, reason: "invalid_data" } unless valid_for_sync?

    begin
      if @wrs.webflow_item_id.present?
        # Update existing Webflow item (only if it's a draft)
        update_webflow_item
      else
        # Create new Webflow item as draft
        create_webflow_item
      end
    rescue WebflowApiError => e
      Rails.logger.error "WebflowAutoSync failed for WRS ##{@wrs.id}: #{e.message}"
      { success: false, error: e.message, status_code: e.status_code }
    rescue => e
      Rails.logger.error "WebflowAutoSync unexpected error for WRS ##{@wrs.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  private

  def should_auto_sync?
    # Only auto-sync if:
    # 1. The record is marked as draft (is_draft = true), OR
    # 2. The record has no webflow_item_id (never been synced)
    # This prevents automatically updating published items
    @wrs.is_draft? || @wrs.webflow_item_id.blank?
  end

  def valid_for_sync?
    # Check that required fields are present
    @wrs.name.present? && @wrs.address.present? && @wrs.slug.present?
  end

  def create_webflow_item
    # Log image availability for debugging
    log_image_status

    # Prepare data with isDraft: true to create as draft
    item_data = @wrs.to_webflow_formatted.merge(isDraft: true)

    response = @webflow_service.create_item(item_data)

    # Update the WRS with the Webflow item ID
    @wrs.update_column(:webflow_item_id, response["id"])

    Rails.logger.info "WebflowAutoSync: Created WRS ##{@wrs.id} in Webflow as draft (#{response['id']})"

    { success: true, action: "created", webflow_item_id: response["id"] }
  end

  def update_webflow_item
    # Only update if it's still a draft
    unless @wrs.is_draft?
      Rails.logger.info "WebflowAutoSync: Skipping WRS ##{@wrs.id} - item is published"
      return { success: false, reason: "item_published" }
    end

    # Log image availability for debugging
    log_image_status

    # Prepare data with isDraft: true to maintain draft status
    item_data = @wrs.to_webflow_formatted.merge(isDraft: true)

    @webflow_service.update_item(@wrs.webflow_item_id, item_data)

    Rails.logger.info "WebflowAutoSync: Updated WRS ##{@wrs.id} in Webflow (#{@wrs.webflow_item_id})"

    { success: true, action: "updated", webflow_item_id: @wrs.webflow_item_id }
  end

  def log_image_status
    # Log which windows have images attached for debugging
    @wrs.windows.each_with_index do |window, index|
      if window.image.attached?
        Rails.logger.info "WebflowAutoSync: Window #{index + 1} has image attached (#{window.image.filename})"
      else
        Rails.logger.info "WebflowAutoSync: Window #{index + 1} has NO image"
      end
    end
  end
end
