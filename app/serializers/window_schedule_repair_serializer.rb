class WindowScheduleRepairSerializer < ActiveModel::Serializer
  attributes :id, :name, :slug, :address, :flat_number, :details,
             :total_vat_included_price, :total_vat_excluded_price,
             :status, :status_color, :grand_total, :created_at, :updated_at

  belongs_to :user
  has_many :windows, serializer: WindowSerializer
end
