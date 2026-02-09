# frozen_string_literal: true

module Avo
  module Fields
    class RoleBadgeField < Avo::Fields::BaseField
      def value
        record.role
      end
    end
  end
end
