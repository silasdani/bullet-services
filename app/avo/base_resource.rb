# frozen_string_literal: true

# Extend Avo's base resource so bulk destroy is available on all index views by default.
# See: https://docs.avohq.io/3.0/guides/bulk_destroy_action_using_customizable_controls.html
module Avo
  class BaseResource < Avo::Resources::Base
    # Include Bulk Destroy in the Actions dropdown for every resource (except excluded).
    # Resources that override actions should call super to keep Bulk Destroy, or add it manually.
    def actions
      return if self.class.bulk_destroy_excluded_resource_names.include?(self.class.name)

      action Avo::Actions::BulkDestroy
    end

    self.index_controls = lambda {
      # Don't show bulk destroy for these resources (add/remove as needed)
      return default_controls if resource.class.name.in?(bulk_destroy_excluded_resource_names)

      action Avo::Actions::BulkDestroy,
             icon: 'heroicons/solid/trash',
             color: 'red',
             label: 'Delete selected',
             style: :outline,
             title: "Delete selected #{resource.plural_name.downcase} (select rows first)"

      default_controls
    }

    class << self
      def bulk_destroy_excluded_resource_names
        %w[
          Avo::Resources::User
          # Add more to exclude from bulk destroy e.g. Avo::Resources::StatusDefinition
        ]
      end
    end
  end
end
