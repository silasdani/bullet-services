# frozen_string_literal: true

# Background job to automatically sync WRS to Webflow
# Runs asynchronously to avoid blocking the main request
# Triggered explicitly by WrsCreationService after all operations (including image attachments) are complete
class AutoSyncToWebflowJob < ApplicationJob
  queue_as :default

  # Retry up to 3 times with exponential backoff
  retry_on WebflowApiError, wait: ->(executions) { (2**executions) + 1 }, attempts: 3
  retry_on StandardError, wait: ->(executions) { (2**executions) + 1 }, attempts: 2

  def perform(wrs_id)
    wrs = WindowScheduleRepair.find_by(id: wrs_id)

    # Skip if WRS no longer exists or was deleted
    return unless wrs&.active?

    # Run the sync
    service = Webflow::AutoSyncService.new(wrs: wrs)
    result = service.call

    if result[:success]
      Rails.logger.info "AutoSyncToWebflowJob: Successfully synced WRS ##{wrs_id} - #{result[:action]}"
    else
      Rails.logger.warn "AutoSyncToWebflowJob: Skipped WRS ##{wrs_id} - #{result[:reason]}"
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "AutoSyncToWebflowJob: WRS ##{wrs_id} not found"
  end
end
