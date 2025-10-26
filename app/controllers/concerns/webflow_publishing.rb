# frozen_string_literal: true

module WebflowPublishing
  extend ActiveSupport::Concern

  def publish_to_webflow
    authorize @window_schedule_repair, :publish_to_webflow?
    return unless webflow_synced?

    execute_webflow_action(:publish, 'published')
  rescue StandardError => e
    handle_webflow_error('publish', e)
  end

  def unpublish_from_webflow
    authorize @window_schedule_repair, :unpublish_from_webflow?
    return unless webflow_synced?

    execute_webflow_action(:unpublish, 'unpublished')
  rescue StandardError => e
    handle_webflow_error('unpublish', e)
  end

  def send_to_webflow
    authorize @window_schedule_repair, :send_to_webflow?
    result = sync_to_webflow
    result[:success] ? handle_sync_success : handle_sync_error(result)
  rescue StandardError => e
    handle_sync_exception(e)
  end

  private

  def webflow_synced?
    return true if @window_schedule_repair.webflow_item_id.present?

    render_error(
      message: 'WRS has not been synced to Webflow yet',
      status: :unprocessable_entity
    )
    false
  end

  def execute_webflow_action(action, past_tense)
    item_service = Webflow::ItemService.new
    collection_id = @window_schedule_repair.webflow_collection_id
    item_ids = [@window_schedule_repair.webflow_item_id]

    item_service.public_send("#{action}_items", collection_id, item_ids)

    @window_schedule_repair.public_send("mark_as_#{action == :publish ? 'published' : 'draft'}!")
    @window_schedule_repair.reload

    render_success(
      data: WindowScheduleRepairSerializer.new(@window_schedule_repair).serializable_hash,
      message: "WRS #{past_tense} to Webflow successfully"
    )
  end

  def handle_webflow_error(action, error)
    Rails.logger.error "Error #{action}ing to Webflow: #{error.message}"
    render_error(
      message: "Failed to #{action} to Webflow",
      details: error.message,
      status: :internal_server_error
    )
  end

  def sync_to_webflow
    Webflow::AutoSyncService.new(wrs: @window_schedule_repair).call
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

  def handle_sync_exception(error)
    Rails.logger.error "Error sending to Webflow: #{error.message}"
    render_error(
      message: 'Failed to send to Webflow',
      details: error.message,
      status: :internal_server_error
    )
  end
end
