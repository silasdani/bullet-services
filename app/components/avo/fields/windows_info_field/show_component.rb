# frozen_string_literal: true

class Avo::Fields::WindowsInfoField::ShowComponent < Avo::Fields::ShowComponent
  def value
    @resource.record
  end
end
