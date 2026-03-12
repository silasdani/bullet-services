# frozen_string_literal: true

class ToolSerializer < ActiveModel::Serializer
  attributes :id, :name, :created_at, :updated_at

  # Price visible to Admin or users with project-level price permission (e.g. contract_manager)
  attribute :price, if: :show_price?

  def show_price?
    return true if scope&.role == 'admin'

    building = object.respond_to?(:window) && object.window&.work_order&.building
    return false unless building && scope

    ProjectRoleResolver.new(user: scope, building: building).can_view_prices?
  end
end
