# frozen_string_literal: true

# Stub for Avo::Cards when Avo Pro (dashboards) is not installed.
# This allows the app to boot. Add the avo_pro gem for full dashboard support.
# See: https://docs.avohq.io/3.0/installation.html

module Avo
  module Cards
    unless const_defined?(:MetricCard, false)
      class MetricCard
        class_attribute :id, :label, :description, :cols, :rows, :prefix, :suffix,
                        :format, :display_header, :refresh_every, :initial_range, :ranges,
                        :visible, instance_accessor: false, default: nil

        self.cols = 1
        self.rows = 1
        self.display_header = true

        def result(value)
          value
        end
      end
    end

    unless const_defined?(:PartialCard, false)
      class PartialCard
        class_attribute :id, :label, :description, :cols, :rows, :partial,
                        :display_header, :visible, instance_accessor: false, default: nil

        self.cols = 1
        self.rows = 1
        self.display_header = true
      end
    end
  end
end
