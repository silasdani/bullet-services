# frozen_string_literal: true

module WorkOrderGeneration
  extend ActiveSupport::Concern

  included do
    before_validation :generate_slug, on: :create
    before_validation :generate_reference_number
    before_validation :set_default_flags, on: :create
  end

  private

  def generate_slug
    return if slug.present?
    return unless building
    return if building.address_string.blank?
    return if flat_number.blank?

    # Use building address for slug
    address_part = building.address_string.parameterize
    self.slug = "#{address_part}-#{flat_number.parameterize}-#{SecureRandom.hex(2)}"
  end

  def generate_reference_number
    return if reference_number.present?

    # Generate a user-friendly reference number: WRS-YYYYMMDD-###
    date_part = Time.current.strftime('%Y%m%d')

    # Find the highest sequence number for today
    today_count = WorkOrder.unscoped
                           .where('reference_number LIKE ?', "WRS-#{date_part}-%")
                           .count

    sequence = format('%03d', today_count + 1)
    self.reference_number = "WRS-#{date_part}-#{sequence}"
  end

  def set_default_flags
    self.is_draft = true if is_draft.nil?
    self.is_archived = false if is_archived.nil?
  end
end
