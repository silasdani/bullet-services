# frozen_string_literal: true

class StatusDefinition < ApplicationRecord
  validates :entity_type, presence: true
  validates :status_key, presence: true, uniqueness: { scope: :entity_type }
  validates :status_label, presence: true
  validates :status_color, presence: true, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: 'must be a valid hex color' }
  validates :display_order, presence: true, numericality: { only_integer: true }

  scope :active, -> { where(is_active: true) }
  scope :for_entity, ->(entity_type) { where(entity_type: entity_type) }
  scope :ordered, -> { order(:display_order, :status_key) }

  after_save :clear_cache
  after_destroy :clear_cache

  private

  def clear_cache
    # Clear cache for this entity type
    Rails.cache.delete("status_definitions/#{entity_type}")

    # Also clear any model-level caches (if the model exists and supports it)
    model_class = entity_type.safe_constantize
    model_class.clear_status_cache! if model_class && model_class.respond_to?(:clear_status_cache!)
  end
end
