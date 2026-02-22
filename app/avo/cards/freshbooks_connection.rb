# frozen_string_literal: true

module Avo
  module Cards
    class FreshbooksConnection < Avo::Cards::PartialCard
      self.id = 'freshbooks_connection'
      self.label = 'FreshBooks'
      self.description = 'OAuth connection status. API check verifies FreshBooks reachability. Reconnect if token expired.'
      self.cols = 1
      self.rows = 1
      self.partial = 'avo/cards/freshbooks_connection'
    end
  end
end
