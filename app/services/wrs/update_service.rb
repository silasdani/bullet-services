# frozen_string_literal: true

module Wrs
  class UpdateService < ApplicationService
    attribute :wrs
    attribute :params, default: -> { {} }

    def call
      result = with_error_handling do
        transaction_result = with_transaction do
          next nil unless update_wrs?

          update_associated_windows
          calculate_totals
        end

        # If transaction failed (returned nil), return nil from the block
        next nil if transaction_result.nil?

        # trigger_webflow_sync if success?  # Disabled - manual sync only via API
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

    def update_wrs?
      unless wrs.update(wrs_attributes)
        add_errors(wrs.errors.full_messages)
        return false
      end

      true
    end

    def update_associated_windows
      return unless params[:windows_attributes]

      params[:windows_attributes].each_value do |window_attrs|
        if window_attrs[:id].present?
          # Update existing window
          update_existing_window(window_attrs)
        else
          # Create new window (skip if marked for destroy or location is blank)
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
      window = wrs.windows.find_by(id: window_id)
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
      window.image.attach(image) if image.present?
    end

    def update_window_fields?(window, window_attrs)
      update_params = {
        location: window_attrs[:location],
        webflow_image_url: window_attrs[:webflow_image_url]
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
      wrs.windows.build(
        location: window_attrs[:location],
        webflow_image_url: window_attrs[:webflow_image_url]
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

    def update_existing_tool(window, tool_attrs)
      tool = window.tools.find(tool_attrs[:id])

      if tool_attrs[:_destroy] == '1'
        tool.destroy
      else
        unless tool.update(
          name: tool_attrs[:name],
          price: tool_attrs[:price] || 0
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
        price: tool_attrs[:price] || 0
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
          price: tool_attrs[:price] || 0
        )

        unless tool.save
          add_errors(tool.errors.full_messages)
          raise ActiveRecord::Rollback
        end
      end
    end

    def calculate_totals
      wrs.save! # This will trigger the before_save callback to recalculate totals
    end

    # def trigger_webflow_sync
    #   WebflowSyncJob.perform_later(wrs.class.name, wrs.id)
    # end

    def wrs_attributes
      {
        name: params[:name],
        building_id: params[:building_id],
        flat_number: params[:flat_number],
        details: params[:details],
        status: params[:status]
      }.compact
    end

    def success_result
      { success: true, wrs: wrs.reload }
    end
  end
end
