# frozen_string_literal: true

class Avo::Fields::RoleBadgeField::ShowComponent < Avo::Fields::ShowComponent
  include Avo::Fields::RoleBadgeField::RoleBadgeStyling

  def role
    return nil unless @resource&.record

    @resource.record.role
  end
end
