# frozen_string_literal: true

module WrsGeneration
  extend ActiveSupport::Concern

  included do
    before_validation :generate_slug, on: :create
    before_validation :generate_reference_number
    before_validation :set_default_webflow_flags, on: :create
    before_save :sync_address_from_building
  end

  private

  def generate_slug
    return if slug.present?
    return unless building
    return if building.address_string.blank?
    return if flat_number.blank?

    # Use building address in Webflow format for slug
    address_part = building.address_string.parameterize
    self.slug = "#{address_part}-#{flat_number.parameterize}-#{SecureRandom.hex(2)}"
  end

  def generate_reference_number
    return if reference_number.present?

    # Generate a user-friendly reference number: WRS-YYYYMMDD-###
    date_part = Time.current.strftime('%Y%m%d')

    # Find the highest sequence number for today
    today_wrs_count = WindowScheduleRepair.unscoped
                                          .where('reference_number LIKE ?', "WRS-#{date_part}-%")
                                          .count

    sequence = format('%03d', today_wrs_count + 1)
    self.reference_number = "WRS-#{date_part}-#{sequence}"
  end

  def set_default_webflow_flags
    self.is_draft = true if is_draft.nil?
    self.is_archived = false if is_archived.nil?
  end

  def sync_address_from_building
    # Sync address column with building address (Webflow format) for backwards compatibility
    # Format: "{building.name}, {building.street}, {building.zipcode}"
    return unless building.present?

    parts = [building.name, building.street, building.zipcode].compact.reject(&:blank?)
    new_address = parts.join(', ')
    write_attribute(:address, new_address) if new_address.present?
  end
end
