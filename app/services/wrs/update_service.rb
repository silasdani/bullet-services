# frozen_string_literal: true

module Wrs
  class UpdateService < ApplicationService
    attribute :wrs
    attribute :params, default: -> { {} }

    def call
      result = with_error_handling do
        with_transaction do
          update_wrs
          update_associated_windows
          calculate_totals
        end

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

    def update_wrs
      unless wrs.update(wrs_attributes)
        add_errors(wrs.errors.full_messages)
        return false
      end

      true
    end

    def update_associated_windows
      return unless params[:windows_attributes]

      # Clear existing windows if we're providing new ones
      # This follows Rails convention for nested attributes
      wrs.windows.destroy_all if params[:windows_attributes].present?

      params[:windows_attributes].each do |_key, window_attrs|
        next if window_attrs[:_destroy] == '1' || window_attrs[:location].blank?

        window = wrs.windows.build(
          location: window_attrs[:location],
          webflow_image_url: window_attrs[:webflow_image_url]
        )

        # Attach image if provided
        window.image.attach(window_attrs[:image]) if window_attrs[:image].present?

        unless window.save
          add_errors(window.errors.full_messages)
          raise ActiveRecord::Rollback
        end

        create_window_tools(window, window_attrs[:tools_attributes]) if window_attrs[:tools_attributes]
      end
    end

    def update_existing_window(window_attrs)
      window = wrs.windows.find(window_attrs[:id])

      if window_attrs[:_destroy] == '1'
        window.destroy
      else
        # Attach image if provided
        window.image.attach(window_attrs[:image]) if window_attrs[:image].present?

        unless window.update(
          location: window_attrs[:location],
          webflow_image_url: window_attrs[:webflow_image_url]
        )
          add_errors(window.errors.full_messages)
          raise ActiveRecord::Rollback
        end

        update_window_tools(window, window_attrs[:tools_attributes]) if window_attrs[:tools_attributes]
      end
    end

    def create_new_window(window_attrs)
      return if window_attrs[:location].blank?

      window = wrs.windows.build(
        location: window_attrs[:location],
        webflow_image_url: window_attrs[:webflow_image_url]
      )

      # Attach image if provided
      window.image.attach(window_attrs[:image]) if window_attrs[:image].present?

      unless window.save
        add_errors(window.errors.full_messages)
        raise ActiveRecord::Rollback
      end

      create_window_tools(window, window_attrs[:tools_attributes]) if window_attrs[:tools_attributes]
    end

    def update_window_tools(window, tools_attributes)
      tools_attributes.each do |_key, tool_attrs|
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
      tools_attributes.each do |_key, tool_attrs|
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
        address: params[:address],
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
