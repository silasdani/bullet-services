# frozen_string_literal: true

class WebflowSyncJob < ApplicationJob
  queue_as :webflow

  retry_on WebflowApiError, wait: :exponentially_longer, attempts: 3

  def perform(model_class, model_id)
    model = model_class.constantize.find(model_id)

    return unless model.respond_to?(:webflow_formatted_data)
    return if model.deleted?

    service = Webflow::ItemService.new

    if model.webflow_item_id.present?
      service.update_item(
        model.webflow_collection_id,
        model.webflow_item_id,
        model.webflow_formatted_data
      )
    else
      response = service.create_item(
        model.webflow_collection_id,
        model.webflow_formatted_data
      )

      model.update!(webflow_item_id: response['id'])
    end
  rescue WebflowApiError => e
    Rails.logger.error "Webflow sync failed for #{model_class}##{model_id}: #{e.message}"
    raise e
  end
end
