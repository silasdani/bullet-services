# frozen_string_literal: true

module Avo
  module Fields
    class UserStatusBadgeField < Avo::Fields::BaseField
      attr_reader :association

      def initialize(id, **args, &)
        super
        @association = args[:association]
      end

      def value
        return nil unless user_for_badge

        user_for_badge.blocked? ? 'blocked' : user_for_badge.role
      end

      def user_for_badge
        return record unless record
        return record if record.is_a?(::User)

        record.try(association || :user)
      end
    end
  end
end
