class WindowScheduleRepairSerializer < ActiveModel::Serializer
  attributes :id, :name, :slug, :webflow_collection_id, :webflow_item_id,
             :webflow_published_on, :reference_number, :address, :flat_number,
             :details, :total_vat_included_price, :total_vat_excluded_price,
             :status, :status_color, :grand_total, :created_at, :updated_at

  belongs_to :user
  has_many :windows
end
