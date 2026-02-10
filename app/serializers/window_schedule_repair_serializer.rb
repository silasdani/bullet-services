# frozen_string_literal: true

class WindowScheduleRepairSerializer < ActiveModel::Serializer
  attributes :id, :name, :slug, :flat_number, :details,
             :total_vat_included_price, :total_vat_excluded_price,
             :status, :status_color, :total, :created_at, :updated_at,
             :deleted_at, :deleted?, :active?, :is_draft, :is_archived,
             :published?, :draft?, :archived?

  def address
    building = load_building_obj
    address_from_building(building) || address_from_object || 'Address not available'
  rescue StandardError => e
    log_address_error(e)
    address_fallback
  end

  # Hide prices for contractors
  def total_vat_included_price
    return nil if scope&.contractor?

    begin
      object.total_vat_included_price
    rescue StandardError => e
      Rails.logger.error "Error getting total_vat_included_price: #{e.message}"
      nil
    end
  end

  def total_vat_excluded_price
    return nil if scope&.contractor?

    begin
      object.total_vat_excluded_price
    rescue StandardError => e
      Rails.logger.error "Error getting total_vat_excluded_price: #{e.message}"
      nil
    end
  end

  def total
    return nil if scope&.contractor?

    begin
      object.total || object.total_vat_included_price || 0
    rescue StandardError => e
      Rails.logger.error "Error getting total: #{e.message}"
      nil
    end
  end

  # Backwards compatibility alias
  def grand_total
    total
  end

  belongs_to :user
  belongs_to :building
  has_many :windows, serializer: WindowSerializer

  def windows
    return [] unless object.respond_to?(:windows)

    windows_list
  rescue StandardError => e
    Rails.logger.error "Error loading windows in serializer: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    []
  end

  def user
    return nil unless object.respond_to?(:user)

    association_loaded?(:user) ? object.user : object.user&.reload
  rescue StandardError => e
    Rails.logger.error "Error loading user in serializer: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    nil
  end

  def building
    return nil unless object.respond_to?(:building)

    building_obj = load_building_obj
    building_obj ? BuildingSerializer.new(building_obj, scope: scope).serializable_hash : nil
  rescue StandardError => e
    Rails.logger.error "Error loading building in serializer: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    nil
  end

  # Soft delete status methods
  def deleted?
    object.respond_to?(:deleted?) ? object.deleted? : false
  rescue StandardError
    false
  end

  def active?
    object.respond_to?(:active?) ? object.active? : true
  rescue StandardError
    true
  end

  # Webflow status methods
  def published?
    object.respond_to?(:published?) ? object.published? : false
  rescue StandardError
    false
  end

  def draft?
    object.respond_to?(:draft?) ? object.draft? : false
  rescue StandardError
    false
  end

  def archived?
    object.respond_to?(:archived?) ? object.archived? : false
  rescue StandardError
    false
  end

  private

  def association_loaded?(name)
    object.association(name).loaded?
  end

  def address_from_building(building)
    return building.full_address if building&.full_address.present?
    return nil unless building

    parts = [building.street, building.city, building.zipcode, building.country].compact.reject(&:blank?)
    parts.join(', ').presence
  end

  def address_from_object
    object.respond_to?(:address) && object.address.present? ? object.address : nil
  end

  def log_address_error(error)
    Rails.logger.error "Error getting address: #{error.message}"
    Rails.logger.error error.backtrace.first(5).join("\n")
  end

  def address_fallback
    object.respond_to?(:address) ? (object.address || 'Address not available') : 'Address not available'
  end

  def windows_list
    association_loaded?(:windows) ? object.windows.to_a : object.windows.load.to_a
  end

  def load_building_obj
    association_loaded?(:building) ? object.building : object.building&.reload
  end
end
