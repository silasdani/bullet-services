class WindowSerializer < ActiveModel::Serializer
  attributes :id, :image, :location, :created_at, :updated_at

  has_many :tools, serializer: ToolSerializer
end
