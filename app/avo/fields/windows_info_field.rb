# frozen_string_literal: true

module Avo
  module Fields
    class WindowsInfoField < Avo::Fields::BaseField
      def value
        record
      end
    end
  end
end
