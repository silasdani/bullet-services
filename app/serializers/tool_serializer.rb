# frozen_string_literal: true

class ToolSerializer < ActiveModel::Serializer
  attributes :id, :name, :created_at, :updated_at

  # Price visible only to Admin role (single source of truth for who sees prices)
  attribute :price, if: :show_price?

  def show_price?
    scope&.role == 'admin'
  end
end
