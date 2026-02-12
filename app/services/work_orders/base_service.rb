# frozen_string_literal: true

# WorkOrders namespace for all work order related services
module WorkOrders
  # Base class for work order services
  class BaseService < ApplicationService
    protected

    def skip_auto_sync_for(work_order)
      work_order.skip_auto_sync = true
    end

    def calculate_and_save_totals(work_order)
      work_order.calculate_totals
      work_order.save!
    end
  end
end
