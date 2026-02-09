# frozen_string_literal: true

module Avo
  module Fields
    module StatusBadgeField
      class IndexComponent < Avo::Fields::IndexComponent
        def wrs
          @resource&.record
        end

        def status
          return 'pending' unless wrs

          wrs.status || 'pending'
        end

        BADGE_CLASS_BY_STATUS = {
          'pending' => 'bg-yellow-100 text-yellow-800',
          'approved' => 'bg-green-100 text-green-800',
          'rejected' => 'bg-red-100 text-red-800',
          'completed' => 'bg-blue-100 text-blue-800'
        }.freeze
        DEFAULT_BADGE_CLASS = 'bg-gray-100 text-gray-800'

        def badge_class
          return DEFAULT_BADGE_CLASS unless wrs

          return 'bg-gray-800 text-white' if wrs.is_archived
          return DEFAULT_BADGE_CLASS if wrs.is_draft

          BADGE_CLASS_BY_STATUS[status] || DEFAULT_BADGE_CLASS
        end

        def badge_text
          return 'Pending' unless wrs

          if wrs.is_archived
            'Archived'
          elsif wrs.is_draft
            'Draft'
          else
            status.humanize
          end
        end
      end
    end
  end
end
