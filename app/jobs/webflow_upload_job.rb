class WebflowUploadJob < ApplicationJob
  queue_as :default

  def perform(window_schedule_repair_id)
    window_schedule_repair = WindowScheduleRepair.find(window_schedule_repair_id)

    begin
      webflow_service = WebflowService.new

      if window_schedule_repair.webflow_item_id.present?
        # Update existing item
        webflow_service.update_item(
          ENV.fetch("WEBFLOW_SITE_ID"),
          window_schedule_repair.webflow_collection_id,
          window_schedule_repair.webflow_item_id,
          webflow_service.send(:window_schedule_repair_data, window_schedule_repair)
        )
      else
        # Create new item
        response = webflow_service.create_item(
          ENV.fetch("WEBFLOW_SITE_ID"),
          window_schedule_repair.webflow_collection_id,
          webflow_service.send(:window_schedule_repair_data, window_schedule_repair)
        )

        # Update the WRS with the Webflow item ID
        if response && response['_id']
          window_schedule_repair.update(webflow_item_id: response['_id'])
        end
      end

      Rails.logger.info "Successfully sent WRS #{window_schedule_repair.id} to Webflow"
    rescue => e
      Rails.logger.error "Failed to send WRS #{window_schedule_repair.id} to Webflow: #{e.message}"
      # You might want to retry the job or notify admins
      raise e
    end
  end
end
