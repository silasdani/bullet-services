# frozen_string_literal: true

class WebflowUploadJob < ApplicationJob
  queue_as :default

  def perform(window_schedule_repair_id)
    window_schedule_repair = WindowScheduleRepair.find(window_schedule_repair_id)

    begin
      item_service = Webflow::ItemService.new

      if window_schedule_repair.webflow_item_id.present?
        # Update existing item
        item_service.update_item(
          window_schedule_repair.webflow_item_id,
          window_schedule_repair.to_webflow_formatted
        )
      else
        # Create new item
        response = item_service.create_item(
          window_schedule_repair.to_webflow_formatted
        )

        # Update the WRS with the Webflow item ID
        window_schedule_repair.update(webflow_item_id: response['id']) if response && response['id']
      end

      Rails.logger.info "Successfully sent WRS #{window_schedule_repair.id} to Webflow"
    rescue StandardError => e
      Rails.logger.error "Failed to send WRS #{window_schedule_repair.id} to Webflow: #{e.message}"
      # You might want to retry the job or notify admins
      raise e
    end
  end
end
