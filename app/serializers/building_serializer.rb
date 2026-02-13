# frozen_string_literal: true

class BuildingSerializer < ActiveModel::Serializer
  attributes :id, :name, :street, :city, :country, :zipcode,
             :latitude, :longitude,
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

  # Count of work orders for this building
  # Use size to avoid extra query if association is loaded, otherwise use count
  attribute :wrs_count do
    if object.association(:work_orders).loaded?
      object.work_orders.size
    else
      object.work_orders.count
    end
  end
end
