# frozen_string_literal: true

module Api
  module V1
    class WindowsController < Api::V1::BaseController
      before_action :set_window, only: %i[show update destroy]

      def index
        @windows = policy_scope(Window)
        render json: @windows
      end

      def show
        authorize @window
        render json: @window
      end

      def create
        @window = Window.new(window_params)
        authorize @window

        if @window.save
          render json: @window, status: :created
        else
          render json: { errors: @window.errors }, status: :unprocessable_content
        end
      end

      def update
        authorize @window
        if @window.update(window_params)
          render json: @window
        else
          render json: { errors: @window.errors }, status: :unprocessable_content
        end
      end

      def destroy
        authorize @window
        @window.destroy
        head :no_content
      end

      private

      def set_window
        @window = Window.find(params[:id])
      end

      def window_params
        params.require(:window).permit(:image, :location, :window_schedule_repair_id)
      end
    end
  end
end
