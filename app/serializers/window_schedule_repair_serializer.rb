class WindowScheduleRepairSerializer < ActiveModel::Serializer
  attributes :id, :name, :slug, :webflow_collection_id, :webflow_item_id,
             :reference_number, :address, :flat_number, :details,
             :total_vat_included_price, :total_vat_excluded_price,
             :status, :status_color, :grand_total, :sitemap_on,
             :created_at, :updated_at

  belongs_to :user
  has_many :windows
end
