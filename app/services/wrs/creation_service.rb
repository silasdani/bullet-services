# frozen_string_literal: true

module Wrs
  # Service for creating and updating WRS records
  class CreationService < BaseService
    attribute :user
    attribute :params, default: -> { {} }

    def call
      create_wrs
    end

    def update(wrs_id)
      @wrs = user.window_schedule_repairs.find(wrs_id)

      with_transaction do
        skip_auto_sync_for(@wrs)
        update_wrs_attributes
        update_windows_and_tools
        calculate_and_save_totals(@wrs)
      end

      trigger_webflow_sync(@wrs)
      success_result(@wrs)
    rescue => e
      add_error("Failed to update WRS: #{e.message}")
      failure_result
    end

    private

    def create_wrs
      with_transaction do
        @wrs = user.window_schedule_repairs.build(wrs_attributes)
        skip_auto_sync_for(@wrs)

        return failure_result unless @wrs.save

        create_windows_and_tools
        calculate_and_save_totals(@wrs)
      end

      trigger_webflow_sync(@wrs) if @wrs.persisted?
      success_result(@wrs)
    rescue => e
      add_error("Failed to create WRS: #{e.message}")
      failure_result
    end

    def wrs_attributes
      {
        name: params[:name],
        address: params[:address],
        flat_number: params[:flat_number],
        details: params[:details],
        is_draft: true
      }
    end

    def update_wrs_attributes
      @wrs.assign_attributes(
        name: params[:name],
        address: params[:address],
        flat_number: params[:flat_number],
        details: params[:details],
        is_draft: true
      )
    end

    def create_windows_and_tools
      return unless params[:windows_attributes]

      windows_attrs = params[:windows_attributes].to_h

      windows_attrs.values.each_with_index do |window_attrs, index|
        next if window_attrs[:location].blank?

        window = @wrs.windows.build(location: window_attrs[:location])
        window.skip_image_validation = true

        create_window_tools(window, window_attrs[:tools_attributes])

        unless window.save
          raise "Failed to save window #{index}: #{window.errors.full_messages}"
        end

        attach_window_image(window, window_attrs[:image])
      end
    end

    def update_windows_and_tools
      return unless params[:windows_attributes]

      windows_attrs = params[:windows_attributes].to_h

      windows_attrs.values.each do |window_attrs|
        next if window_attrs[:location].blank?

        if window_attrs[:id].present?
          update_existing_window(window_attrs)
        else
          create_new_window(window_attrs)
        end
      end
    end

    def update_existing_window(window_attrs)
      window = @wrs.windows.find(window_attrs[:id])
      window.assign_attributes(location: window_attrs[:location])

      update_window_tools(window, window_attrs[:tools_attributes])

      unless window.save
        raise "Failed to save updated window: #{window.errors.full_messages}"
      end

      if window_attrs[:image].present? && window_attrs[:image].respond_to?(:content_type)
        window.image.attach(window_attrs[:image])
      end
    end

    def create_new_window(window_attrs)
      window = @wrs.windows.build(location: window_attrs[:location])
      window.skip_image_validation = true

      create_window_tools(window, window_attrs[:tools_attributes])

      unless window.save
        raise "Failed to save new window: #{window.errors.full_messages}"
      end

      attach_window_image(window, window_attrs[:image])
    end

    def create_window_tools(window, tools_attrs)
      return unless tools_attrs

      tools_attrs = tools_attrs.to_h if tools_attrs.respond_to?(:to_h)

      tools_attrs.values.each do |tool_attrs|
        next if tool_attrs[:name].blank?

        window.tools.build(
          name: tool_attrs[:name],
          price: tool_attrs[:price] || 0
        )
      end
    end

    def update_window_tools(window, tools_attrs)
      return unless tools_attrs

      tools_attrs = tools_attrs.to_h if tools_attrs.respond_to?(:to_h)

      window.tools.destroy_all

      tools_attrs.values.each do |tool_attrs|
        next if tool_attrs[:name].blank?

        window.tools.create!(
          name: tool_attrs[:name],
          price: tool_attrs[:price] || 0
        )
      end
    end

    def attach_window_image(window, image)
      return unless image.present? && image.respond_to?(:content_type)

      begin
        window.image.attach(image)
        window.skip_image_validation = false
      rescue => e
        log_error("Error attaching image to window: #{e.message}")
        window.skip_image_validation = false
      end
    end

    def success_result(wrs)
      { success: true, wrs: wrs }
    end

    def failure_result
      { success: false, errors: errors }
    end
  end
end
