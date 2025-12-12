# frozen_string_literal: true

module WebflowSyncHelpers
  extend ActiveSupport::Concern

  private

  def sync_to_webflow
    Webflow::AutoSyncService.new(wrs: @window_schedule_repair).call
  end

  def sync_to_webflow_with_publish
    # Force sync even if published, as we're about to republish
    item_service = Webflow::ItemService.new
    item_data = build_draft_item_data

    update_item_before_publish(item_service, item_data)
  rescue WebflowApiError => e
    handle_webflow_sync_error(e)
  rescue StandardError => e
    handle_unexpected_sync_error(e)
  end

  def build_draft_item_data
    @window_schedule_repair.to_webflow_formatted.merge(isDraft: true)
  end

  def update_item_before_publish(item_service, item_data)
    item_service.update_item(
      @window_schedule_repair.webflow_collection_id,
      @window_schedule_repair.webflow_item_id,
      item_data
    )

    { success: true }
  end

  def handle_webflow_sync_error(error)
    Rails.logger.error "Error syncing before publish: #{error.message}"
    { success: false, error: error.message, status_code: error.status_code }
  end

  def handle_unexpected_sync_error(error)
    Rails.logger.error "Unexpected error syncing before publish: #{error.message}"
    { success: false, error: error.message }
  end

  def handle_sync_success
    @window_schedule_repair.reload
    render_success(
      data: WindowScheduleRepairSerializer.new(@window_schedule_repair).serializable_hash,
      message: 'WRS sent to Webflow successfully'
    )
  end

  def handle_sync_error(result)
    render_error(
      message: 'Failed to send to Webflow',
      details: result[:reason] || result[:error]
    )
  end

  def handle_publish_sync_error(result)
    render_error(
      message: 'Failed to sync data before publishing',
      details: result[:error] || result[:reason],
      status: :unprocessable_entity
    )
  end

  def handle_sync_exception(error)
    Rails.logger.error "Error sending to Webflow: #{error.message}"
    render_error(
      message: 'Failed to send to Webflow',
      details: error.message,
      status: :internal_server_error
    )
  end
end
