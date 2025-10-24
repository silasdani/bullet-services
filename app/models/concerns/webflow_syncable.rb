# frozen_string_literal: true

module WebflowSyncable
  extend ActiveSupport::Concern

  included do
    attr_accessor :skip_webflow_sync

    after_commit :auto_sync_to_webflow,
                 on: %i[create update],
                 if: :should_auto_sync_to_webflow?
  end

  def webflow_formatted_data
    raise NotImplementedError, 'Implement #webflow_formatted_data'
  end

  def webflow_collection_id
    raise NotImplementedError, 'Implement #webflow_collection_id'
  end

  # Alias for backward compatibility with tests
  def should_auto_sync_to_webflow?
    should_sync_to_webflow?
  end

  private

  def should_sync_to_webflow?
    !deleted? &&
      !skip_webflow_sync &&
      webflow_collection_id.present?
  end

  def auto_sync_to_webflow
    WebflowSyncJob.perform_later(self.class.name, id)
  end
end
