# frozen_string_literal: true

module StatusMetadata
  extend ActiveSupport::Concern

  included do
    # Cache status definitions in memory (rarely changes)
    def self.status_definitions_cache
      @status_definitions_cache ||= Rails.cache.fetch("status_definitions/#{name}", expires_in: 1.hour) do
        StatusDefinition.where(entity_type: name, is_active: true)
                        .index_by(&:status_key)
      end
    end

    # Clear cache when status definitions change
    def self.clear_status_cache!
      @status_definitions_cache = nil
      Rails.cache.delete("status_definitions/#{name}")
    end
  end

  def status_metadata
    self.class.status_definitions_cache[status.to_s]
  end

  def status_label
    status_metadata&.status_label || status.to_s.humanize
  end

  def status_color
    status_metadata&.status_color || '#CCCCCC'
  end
end
