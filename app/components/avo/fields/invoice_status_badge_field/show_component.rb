# frozen_string_literal: true

module Avo
  module Fields
    module InvoiceStatusBadgeField
      class ShowComponent < Avo::Fields::ShowComponent
        def invoice
          @resource&.record
        end

        def status
          return 'draft' unless invoice

          invoice.final_status || invoice.status || 'draft'
        end

        def badge_class
          return 'bg-gray-100 text-gray-800' unless invoice

          case status.downcase
          when 'paid'
            'bg-green-100 text-green-800'
          when 'sent', 'viewed'
            'bg-blue-100 text-blue-800'
          when 'voided'
            'bg-red-100 text-red-800'
          else
            'bg-gray-100 text-gray-800' # draft and unknown
          end
        end
      end
    end
  end
end
