class WindowScheduleRepairSerializer < ActiveModel::Serializer
  attributes :id, :name, :slug, :address, :flat_number, :details,
             :total_vat_included_price, :total_vat_excluded_price,
             :status, :status_color, :grand_total, :created_at, :updated_at,
             :deleted_at, :deleted, :active

  belongs_to :user
  has_many :windows, serializer: WindowSerializer

  # Ensure windows are loaded properly
  def windows
    begin
      return [] unless object.respond_to?(:windows)
      return [] unless object.windows.any?
      object.windows
    rescue => e
      Rails.logger.error "Error loading windows in serializer: #{e.message}"
      []
    end
  end

  # Ensure user is loaded
  def user
    begin
      return nil unless object.respond_to?(:user)
      object.user
    rescue => e
      Rails.logger.error "Error loading user in serializer: #{e.message}"
      nil
    end
  end

  # Soft delete status methods
  def deleted
    object.deleted?
  end

  def active
    object.active?
  end
end
