# frozen_string_literal: true

# Stub for Avo::Dashboards::BaseDashboard when Avo Pro (dashboards) is not installed.
# This allows the app to boot. Add the avo_pro gem for full dashboard support.

module Avo
  module Dashboards
    unless const_defined?(:BaseDashboard, false)
      class BaseDashboard
        class_attribute :id, :name, :description, :grid_cols, instance_accessor: false, default: nil

        self.grid_cols = 3

        def card(klass, **options)
          # no-op when Pro not installed
        end

        def divider(**options)
          # no-op when Pro not installed
        end
      end
    end
  end
end
