# frozen_string_literal: true

module Avo
  module Fields
    class UserStatusBadgeField
      module StatusDefinitionStyling
        ENTITY_TYPE = 'User'

        def user
          return @user if defined?(@user)

          record = @resource&.record
          return @user = nil unless record

          @user = if record.is_a?(::User)
                    record
                  elsif @field.respond_to?(:user_for_badge)
                    @field.user_for_badge
                  else
                    record.try(:user)
                  end
        end

        def effective_status_key
          return nil unless user

          return 'blocked' if user.blocked?

          (user.role || 'client').to_s
        end

        def status_definition
          return nil unless effective_status_key

          @status_definition ||= StatusDefinition
                                 .for_entity(ENTITY_TYPE)
                                 .active
                                 .find_by(status_key: effective_status_key)
        end

        def badge_label
          status_definition&.status_label || effective_status_key&.humanize || 'Unknown'
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
          r, g, b = hex_to_normalized_rgb(hex)
          rs, gs, bs = [r, g, b].map { |component| linearize(component) }
          (0.2126 * rs) + (0.7152 * gs) + (0.0722 * bs)
        end

        def hex_to_normalized_rgb(hex)
          [
            hex[0..1].to_i(16) / 255.0,
            hex[2..3].to_i(16) / 255.0,
            hex[4..5].to_i(16) / 255.0
          ]
        end

        def linearize(component)
          component <= 0.03928 ? component / 12.92 : ((component + 0.055) / 1.055)**2.4
        end
      end
    end
  end
end
