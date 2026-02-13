# frozen_string_literal: true

module WorkOrders
  class CreationService < ApplicationService
    attribute :user
    attribute :params, default: -> { {} }

    def call
      service_result = nil

      with_error_handling do
        service_result = with_transaction do
          next nil unless create_work_order?

          create_associated_windows
          recalculate_totals

          success_result
        end
      end

      if service_result.nil? || failure?
        Rails.logger.error "Service failed with errors: #{errors.inspect}"
        { success: false, errors: errors }
      else
        service_result
      end
    end

    private

    def create_work_order?
      @work_order = user.work_orders.build(work_order_attributes)

      unless @work_order.save!
        add_errors(@work_order.errors.full_messages)
        return false
      end

      true
    end

    def create_associated_windows
      return unless params[:windows_attributes]

      params[:windows_attributes].each_value do |window_attrs|
        next if window_attrs[:location].blank?

        create_single_window(window_attrs)
      end
    end

    def create_single_window(window_attrs)
      window = build_window(window_attrs)
      attach_window_image(window, window_attrs[:image])
      return unless save_window(window)

      create_window_tools(window, window_attrs[:tools_attributes]) if window_attrs[:tools_attributes]
    end

    def build_window(window_attrs)
      @work_order.windows.build(
        location: window_attrs[:location]
      )
    end

    def attach_window_image(window, image)
      return unless image.present?

      window.images.attach(image)
    end

    def save_window(window)
      if window.save
        true
      else
        add_errors(window.errors.full_messages)
        raise ActiveRecord::Rollback
      end
    end

    def create_window_tools(window, tools_attributes)
      tools_attributes.each_value do |tool_attrs|
        next if tool_attrs[:name].blank?

        tool = window.tools.build(
          name: tool_attrs[:name],
          price: supervisor_tool_price(tool_attrs)
        )

        unless tool.save
          add_errors(tool.errors.full_messages)
          raise ActiveRecord::Rollback
        end
      end
    end

    # Supervisors don't input prices — use the default price for the tool name.
    # Non-supervisors use the price sent from the frontend.
    def supervisor_tool_price(tool_attrs)
      if user.supervisor?
        Tool.default_price_for_name(tool_attrs[:name]) || 0
      else
        tool_attrs[:price] || 0
      end
    end

    def recalculate_totals
      @work_order.save! # This will trigger the before_save callback to recalculate totals
    end

    def work_order_attributes
      {
        name: params[:name],
        building_id: params[:building_id],
        flat_number: params[:flat_number],
        details: params[:details],
        status: :pending,
        work_type: params[:work_type].presence || :wrs
      }.compact
    end

    def success_result
      notify_admin_supervisor_created if user.supervisor?

      { success: true, work_order: @work_order }
    end

    def notify_admin_supervisor_created
      Notifications::AdminNotificationService.new(
        work_order: @work_order,
        notification_type: 'supervisor_wrs_created',
        title: 'Work order created by supervisor (review pricing)',
        message: "#{user.name} created \"#{@work_order.name}\" with default prices. Please review pricing.",
        metadata: { created_by_user_id: user.id }
      ).call
    end
  end
end
