# frozen_string_literal: true

module Avo
  module Fields
    module WindowsInfoField
      class ShowComponent < Avo::Fields::ShowComponent
        def value
          @resource.record
        end
      end
    end
  end
end
