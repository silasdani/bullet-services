# frozen_string_literal: true

module Avo
  module Actions
    # Bulk destroy selected records. Per Avo guide:
    # https://docs.avohq.io/3.0/guides/bulk_destroy_action_using_customizable_controls.html
    class BulkDestroy < Avo::BaseAction
      self.name = 'Bulk Destroy'
      self.message = lambda {
        tag.div do
          safe_join([
                      "Are you sure you want to delete these #{query.count} records?",
                      tag.div(class: 'text-sm text-gray-500 mt-2 mb-2 font-bold') do
                        'These records will be permanently deleted:'
                      end,
                      tag.ul(class: 'ml-4 overflow-y-scroll max-h-64') do
                        safe_join(query.map do |record|
                          model = record.respond_to?(:record) ? record.record : record
                          title = ::Avo.resource_manager
                            .get_resource_by_model_class(model.class).new(record: model).record_title
                          tag.li(class: 'text-sm text-gray-500') { "- #{title}" }
                        end)
                      end,
                      tag.div(class: 'text-sm text-red-500 mt-2 font-bold') do
                        'This action cannot be undone.'
                      end
                    ])
        end
      }

      # Show in Actions dropdown on index when rows are selected (batch context).
      def visible?(resource:, **)
        return true if resource.nil?

        true
      end

      def handle(query:, **)
        count = query.count
        query.each do |item|
          (item.respond_to?(:record) ? item.record : item).destroy!
        end
        succeed "Deleted #{count} records"
      rescue StandardError => e
        error("Failed to delete records: #{e.message}")
      end
    end
  end
end
