# frozen_string_literal: true

module WorkOrders
  class UpdateService < ApplicationService
    attribute :work_order
    attribute :params, default: -> { {} }
    attribute :current_user, default: nil # Used to check if supervisor (strips tool prices)

    def call
      result = with_error_handling do
        transaction_result = with_transaction do
          next nil unless update_work_order?

          update_associated_windows
          calculate_totals
        end

        # If transaction failed (returned nil), return nil from the block
        next nil if transaction_result.nil?

        success_result
      end

      if result.nil?
        Rails.logger.error "Service failed with errors: #{errors.inspect}"
        { success: false, errors: errors }
      else
        result
      end
    end

    private

    def update_work_order?
      unless work_order.update(work_order_attributes)
        add_errors(work_order.errors.full_messages)
        return false
      end

      true
    end

    def update_associated_windows
      return unless params[:windows_attributes]

      params[:windows_attributes].each_value do |window_attrs|
        if window_attrs[:id].present?
          update_existing_window(window_attrs)
        else
          next if window_attrs[:_destroy] == '1' || window_attrs[:location].blank?

          create_new_window(window_attrs)
        end
      end
    end

    def update_existing_window(window_attrs)
      window = find_window(window_attrs[:id])
      return unless window

      if window_attrs[:_destroy] == '1'
        window.destroy
      else
        update_window_attributes(window, window_attrs)
      end
    end

    def find_window(window_id)
      window = work_order.windows.find_by(id: window_id)
      return window if window

      add_errors("Window with id #{window_id} not found")
      raise ActiveRecord::Rollback
    end

    def update_window_attributes(window, window_attrs)
      attach_window_image_if_provided(window, window_attrs[:image])
      return unless update_window_fields?(window, window_attrs)

      update_window_tools(window, window_attrs[:tools_attributes]) if window_attrs[:tools_attributes]
    end

    def attach_window_image_if_provided(window, image)
      return unless image.present?

      window.images.attach(image)
    end

    def update_window_fields?(window, window_attrs)
      update_params = {
        location: window_attrs[:location]
      }.compact

      return true if window.update(update_params)

      add_errors(window.errors.full_messages)
      raise ActiveRecord::Rollback
    end

    def create_new_window(window_attrs)
      return if window_attrs[:location].blank?

      window = build_new_window(window_attrs)
      attach_window_image_if_provided(window, window_attrs[:image])
      return unless save_new_window?(window)

      create_window_tools(window, window_attrs[:tools_attributes]) if window_attrs[:tools_attributes]
    end

    def build_new_window(window_attrs)
      work_order.windows.build(
        location: window_attrs[:location]
      )
    end

    def save_new_window?(window)
      return true if window.save

      add_errors(window.errors.full_messages)
      raise ActiveRecord::Rollback
    end

    def update_window_tools(window, tools_attributes)
      tools_attributes.each_value do |tool_attrs|
        if tool_attrs[:id].present?
          update_existing_tool(window, tool_attrs)
        else
          create_new_tool(window, tool_attrs)
        end
      end
    end

    def tool_price(tool_attrs)
      current_user&.supervisor? ? 0 : (tool_attrs[:price] || 0)
    end

    def update_existing_tool(window, tool_attrs)
      tool = window.tools.find(tool_attrs[:id])

      if tool_attrs[:_destroy] == '1'
        tool.destroy
      else
        unless tool.update(
          name: tool_attrs[:name],
          price: tool_price(tool_attrs)
        )
          add_errors(tool.errors.full_messages)
          raise ActiveRecord::Rollback
        end
      end
    end

    def create_new_tool(window, tool_attrs)
      return if tool_attrs[:name].blank?

      tool = window.tools.build(
        name: tool_attrs[:name],
        price: tool_price(tool_attrs)
      )

      return if tool.save

      add_errors(tool.errors.full_messages)
      raise ActiveRecord::Rollback
    end

    def create_window_tools(window, tools_attributes)
      tools_attributes.each_value do |tool_attrs|
        next if tool_attrs[:name].blank?

        tool = window.tools.build(
          name: tool_attrs[:name],
          price: tool_price(tool_attrs)
        )

        unless tool.save
          add_errors(tool.errors.full_messages)
          raise ActiveRecord::Rollback
        end
      end
    end

    def calculate_totals
      work_order.save! # This will trigger the before_save callback to recalculate totals
    end

    def work_order_attributes
      {
        name: params[:name],
        building_id: params[:building_id],
        flat_number: params[:flat_number],
        details: params[:details],
        status: params[:status],
        work_type: params[:work_type]
      }.compact
    end

    def success_result
      { success: true, work_order: work_order.reload }
    end
  end
end
