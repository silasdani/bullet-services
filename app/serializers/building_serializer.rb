# frozen_string_literal: true

class BuildingSerializer < ActiveModel::Serializer
  attributes :id, :name, :street, :city, :country, :zipcode,
             :created_at, :updated_at, :deleted_at

  # Address string representation
  attribute :address_string do
    object.address_string
  end

  attribute :full_address do
    object.full_address
  end

  attribute :display_name do
    object.display_name
  end

  # Count of WRS for this building
  # Use size to avoid extra query if association is loaded, otherwise use count
  attribute :wrs_count do
    if object.association(:window_schedule_repairs).loaded?
      object.window_schedule_repairs.size
    else
      object.window_schedule_repairs.count
    end
  end
end
