# frozen_string_literal: true

module Avo
  module Fields
    class StatusBadgeField
      module StatusDefinitionStyling
        ENTITY_TYPE = 'WindowScheduleRepair'

        def wrs
          @resource&.record
        end

        def effective_status_key
          return nil unless wrs
          return 'archived' if wrs.is_archived
          return 'draft' if wrs.is_draft

          (wrs.status || 'pending').to_s
        end

        def status_definition
          return nil unless effective_status_key

          @status_definition ||= StatusDefinition.for_entity(ENTITY_TYPE).active.find_by(status_key: effective_status_key)
        end

        def badge_label
          status_definition&.status_label || effective_status_key&.humanize || 'Pending'
        end

        def badge_bg_color
          status_definition&.status_color || '#6f6f6f'
        end

        def badge_text_color
          luminance(badge_bg_color) < 0.4 ? '#ffffff' : '#1f2937'
        end

        def badge_style
          "background-color: #{badge_bg_color}; color: #{badge_text_color}"
        end

        private

        def luminance(hex)
          hex = hex.delete('#')
          r = hex[0..1].to_i(16) / 255.0
          g = hex[2..3].to_i(16) / 255.0
          b = hex[4..5].to_i(16) / 255.0
          [r, g, b].map { |c| c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }.then do |rs, gs, bs|
            0.2126 * rs + 0.7152 * gs + 0.0722 * bs
          end
        end
      end
    end
  end
end
