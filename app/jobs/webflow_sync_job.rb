# frozen_string_literal: true

class WebflowSyncJob < ApplicationJob
  queue_as :webflow

  retry_on WebflowApiError, wait: :exponentially_longer, attempts: 3

  def perform(model_class, model_id)
    model = find_model(model_class, model_id)
    return unless valid_for_sync?(model)

    sync_to_webflow(model)
  rescue WebflowApiError => e
    Rails.logger.error "Webflow sync failed for #{model_class}##{model_id}: #{e.message}"
    raise e
  end

  private

  def find_model(model_class, model_id)
    model_class.constantize.find(model_id)
  end

  def valid_for_sync?(model)
    model.respond_to?(:webflow_formatted_data) && !model.deleted?
  end

  def sync_to_webflow(model)
    service = Webflow::ItemService.new

    if model.webflow_item_id.present?
      update_existing_item(service, model)
    else
      create_new_item(service, model)
    end
  end

  def update_existing_item(service, model)
    service.update_item(
      model.webflow_collection_id,
      model.webflow_item_id,
      model.webflow_formatted_data
    )
  end

  def create_new_item(service, model)
    response = service.create_item(
      model.webflow_collection_id,
      model.webflow_formatted_data
    )

    model.update!(webflow_item_id: response['id'])
  end
end
