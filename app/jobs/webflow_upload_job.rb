# frozen_string_literal: true

class WebflowUploadJob < ApplicationJob
  queue_as :default

  def perform(window_schedule_repair_id)
    @wrs = WindowScheduleRepair.find(window_schedule_repair_id)
    @collection_id = @wrs.webflow_collection_id
    return unless @collection_id.present?

    sync_to_webflow
    Rails.logger.info "Successfully sent WRS #{@wrs.id} to Webflow"
  rescue StandardError => e
    Rails.logger.error "Failed to send WRS #{@wrs.id} to Webflow: #{e.message}"
    raise e
  end

  private

  def sync_to_webflow
    if @wrs.webflow_item_id.present?
      update_webflow_item
    else
      create_webflow_item
    end
  end

  def update_webflow_item
    item_service.update_item(
      @collection_id,
      @wrs.webflow_item_id,
      @wrs.to_webflow_formatted
    )
  end

  def create_webflow_item
    response = item_service.create_item(
      @collection_id,
      @wrs.to_webflow_formatted
    )
    @wrs.update(webflow_item_id: response['id']) if response && response['id']
  end

  def item_service
    @item_service ||= Webflow::ItemService.new
  end
end
