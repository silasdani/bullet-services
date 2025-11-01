# frozen_string_literal: true

class WindowScheduleRepairSerializer < ActiveModel::Serializer
  attributes :id, :name, :slug, :address, :flat_number, :details,
             :total_vat_included_price, :total_vat_excluded_price,
             :status, :status_color, :grand_total, :created_at, :updated_at,
             :deleted_at, :deleted, :active, :last_published, :is_draft, :is_archived,
             :published, :draft, :archived, :webflow_item_id

  belongs_to :user
  belongs_to :building
  has_many :windows, serializer: WindowSerializer

  # Ensure windows are loaded properly
  def windows
    return [] unless object.respond_to?(:windows)
    return [] unless object.windows.any?

    object.windows
  rescue StandardError => e
    Rails.logger.error "Error loading windows in serializer: #{e.message}"
    []
  end

  # Ensure user is loaded
  def user
    return nil unless object.respond_to?(:user)

    object.user
  rescue StandardError => e
    Rails.logger.error "Error loading user in serializer: #{e.message}"
    nil
  end

  # Ensure building is loaded
  def building
    return nil unless object.respond_to?(:building)

    object.building
  rescue StandardError => e
    Rails.logger.error "Error loading building in serializer: #{e.message}"
    nil
  end

  # Soft delete status methods
  def deleted
    object.deleted?
  end

  def active
    object.active?
  end

  # Webflow status methods
  def published
    object.published?
  end

  def draft
    object.draft?
  end

  def archived
    object.archived?
  end
end
