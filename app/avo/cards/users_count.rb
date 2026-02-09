# frozen_string_literal: true

module Avo
  module Cards
    class UsersCount < Avo::Cards::MetricCard
      self.id = 'users_count'
      self.label = 'Users'
      self.description = 'Total number of users'
      self.cols = 1
      self.rows = 1

      def query
        result User.count
      end
    end
  end
end
