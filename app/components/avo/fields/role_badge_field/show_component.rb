# frozen_string_literal: true

class Avo::Fields::RoleBadgeField::ShowComponent < Avo::Fields::ShowComponent
  def role
    return nil unless @resource&.record

    @resource.record.role
  end

  def badge_class
    return 'bg-gray-100 text-gray-800' unless role

    case role
    when 'client'
      'bg-blue-100 text-blue-800'
    when 'contractor'
      'bg-green-100 text-green-800'
    when 'admin'
      'bg-yellow-100 text-yellow-800'
    when 'surveyor'
      'bg-red-100 text-red-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
end
