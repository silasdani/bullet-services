# frozen_string_literal: true

class ToolSerializer < ActiveModel::Serializer
  attributes :id, :name, :created_at, :updated_at

  # Hide price for contractors and supervisors
  attribute :price, if: :show_price?

  def show_price?
    !scope&.contractor? && !scope&.supervisor?
  end
end
