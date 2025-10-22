# frozen_string_literal: true

# WRS namespace for all Window Schedule Repair related services
module Wrs
  # Base class for WRS services
  class BaseService < ApplicationService
    protected

    def skip_auto_sync_for(wrs)
      wrs.skip_auto_sync = true
    end

    def trigger_webflow_sync(wrs)
      return unless wrs.is_draft? || wrs.webflow_item_id.blank?
      return if wrs.deleted?

      AutoSyncToWebflowJob.perform_later(wrs.id)
    end

    def calculate_and_save_totals(wrs)
      wrs.calculate_totals
      wrs.save!
    end
  end
end
