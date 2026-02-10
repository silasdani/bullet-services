# frozen_string_literal: true

module Api
  module V1
    class WindowsController < Api::V1::BaseController
      before_action :set_window, only: %i[show update destroy]

      def index
        @windows = policy_scope(Window).includes(:tools, images_attachments: :blob)

        serialized_data = @windows.map do |window|
          WindowSerializer.new(window).serializable_hash
        end

        render_success(data: serialized_data)
      end

      def show
        authorize @window

        serialized_data = WindowSerializer.new(@window).serializable_hash
        render_success(data: serialized_data)
      end

      def create
        @window = Window.new(window_params)
        authorize @window

        if @window.save
          serialized_data = WindowSerializer.new(@window).serializable_hash
          render_success(
            data: serialized_data,
            message: 'Window created successfully',
            status: :created
          )
        else
          render_error(
            message: 'Failed to create window',
            details: @window.errors.full_messages
          )
        end
      end

      def update
        authorize @window

        if @window.update(window_params)
          serialized_data = WindowSerializer.new(@window).serializable_hash
          render_success(
            data: serialized_data,
            message: 'Window updated successfully'
          )
        else
          render_error(
            message: 'Failed to update window',
            details: @window.errors.full_messages
          )
        end
      end

      def destroy
        authorize @window
        @window.destroy
        head :no_content
      end

      private

      def set_window
        @window = Window.includes(:tools, images_attachments: :blob).find(params[:id])
      end

      def window_params
        params.require(:window).permit(:image, :location, :window_schedule_repair_id)
      end
    end
  end
end
