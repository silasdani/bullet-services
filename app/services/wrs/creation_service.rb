# frozen_string_literal: true

module Wrs
  class CreationService < ApplicationService
    attribute :user
    attribute :params, default: -> { {} }

    def call
      with_error_handling do
        with_transaction do
          create_wrs
          create_associated_windows
          calculate_totals
        end

        trigger_webflow_sync if @wrs.persisted?
        success_result
      end
    end

    private

    def create_wrs
      @wrs = user.window_schedule_repairs.build(wrs_attributes)

      unless @wrs.save
        add_errors(@wrs.errors.full_messages)
        return false
      end

      true
    end

    def create_associated_windows
      return unless params[:windows_attributes]

      params[:windows_attributes].each do |window_attrs|
        next if window_attrs[:location].blank?

        window = @wrs.windows.build(
          location: window_attrs[:location],
          webflow_image_url: window_attrs[:webflow_image_url]
        )

        unless window.save
          add_errors(window.errors.full_messages)
          raise ActiveRecord::Rollback
        end

        create_window_tools(window, window_attrs[:tools_attributes]) if window_attrs[:tools_attributes]
      end
    end

    def create_window_tools(window, tools_attributes)
      tools_attributes.each do |tool_attrs|
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
      @wrs.calculate_totals!
    end

    def trigger_webflow_sync
      WebflowSyncJob.perform_later(@wrs.class.name, @wrs.id)
    end

    def wrs_attributes
      {
        name: params[:name],
        address: params[:address],
        flat_number: params[:flat_number],
        details: params[:details],
        status: :pending
      }
    end

    def success_result
      { success: true, data: @wrs }
    end
  end
end
