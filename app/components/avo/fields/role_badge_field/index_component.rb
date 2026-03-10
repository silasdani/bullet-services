# frozen_string_literal: true

class Avo::Fields::RoleBadgeField::IndexComponent < Avo::Fields::IndexComponent
  include Avo::Fields::RoleBadgeField::RoleBadgeStyling

  def role
    return nil unless @resource&.record

    @resource.record.role
  end
end
