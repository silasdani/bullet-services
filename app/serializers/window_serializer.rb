class WindowSerializer < ActiveModel::Serializer
  attributes :id, :image, :location, :created_at, :updated_at

  belongs_to :window_schedule_repair
end
