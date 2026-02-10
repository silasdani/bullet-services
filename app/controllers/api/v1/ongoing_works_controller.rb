# frozen_string_literal: true

module Api
  module V1
    class OngoingWorksController < Api::V1::BaseController
      before_action :set_window_schedule_repair, only: %i[index create]
      before_action :set_ongoing_work, only: %i[show update destroy]

      # GET /api/v1/window_schedule_repairs/:window_schedule_repair_id/ongoing_works
      def index
        authorize @window_schedule_repair, :show?

        ongoing_works = OngoingWork.where(window_schedule_repair: @window_schedule_repair)
                                   .includes(:user)
                                   .order(work_date: :desc, created_at: :desc)
                                   .page(@page)
                                   .per(@per_page)

        render_success(
          data: ongoing_works.map { |ow| serialize_ongoing_work(ow) },
          meta: pagination_meta(ongoing_works)
        )
      end

      # GET /api/v1/ongoing_works/:id
      def show
        authorize @ongoing_work.window_schedule_repair, :show?

        render_success(
          data: serialize_ongoing_work(@ongoing_work)
        )
      end

      # POST /api/v1/window_schedule_repairs/:window_schedule_repair_id/ongoing_works
      def create
        authorize OngoingWork, :create?
        authorize @window_schedule_repair, :show?

        ongoing_work = build_ongoing_work

        if ongoing_work.save
          attach_images(ongoing_work) if params[:images].present?
          create_work_update_notification(ongoing_work)
          render_create_success(ongoing_work)
        else
          render_create_error(ongoing_work)
        end
      end

      # PATCH /api/v1/ongoing_works/:id
      def update
        authorize @ongoing_work

        # Attach images before update so validation can check them
        attach_images(@ongoing_work) if params[:images].present?

        if update_ongoing_work
          render_update_success
        else
          render_update_error
        end
      end

      # DELETE /api/v1/ongoing_works/:id
      def destroy
        authorize @ongoing_work
        @ongoing_work.destroy

        render_success(
          data: {},
          message: 'Ongoing work deleted successfully'
        )
      end

      private

      def set_window_schedule_repair
        @window_schedule_repair = WindowScheduleRepair.find(params[:window_schedule_repair_id])
      end

      def set_ongoing_work
        @ongoing_work = OngoingWork.find(params[:id])
      end

      def serialize_ongoing_work(ongoing_work)
        {
          id: ongoing_work.id,
          work_order_id: ongoing_work.work_order_id,
          description: ongoing_work.description,
          work_date: ongoing_work.work_date,
          user_id: ongoing_work.user_id,
          user_name: ongoing_work.user.name || ongoing_work.user.email,
          images: ongoing_work.image_urls
        }
      end

      def build_work_update_message
        user_name = current_user.name || current_user.email
        "#{user_name} uploaded work photos for #{@window_schedule_repair.name}"
      end

      def build_ongoing_work
        OngoingWork.new(
          window_schedule_repair: @window_schedule_repair,
          user: current_user,
          description: params[:description],
          work_date: params[:work_date] || Date.current
        )
      end

      def attach_images(ongoing_work)
        images_array = if params[:images].is_a?(Hash) || params[:images].is_a?(ActionController::Parameters)
                         params[:images].values
                       else
                         Array(params[:images])
                       end
        ongoing_work.images.attach(images_array) if images_array.any?
      end

      def create_work_update_notification(ongoing_work)
        # Contractors should not send work update notifications
        return if current_user.contractor?

        Notifications::CreateService.new(
          user: @window_schedule_repair.user,
          window_schedule_repair: @window_schedule_repair,
          notification_type: :work_update,
          title: 'Work Update',
          message: build_work_update_message,
          metadata: build_notification_metadata(ongoing_work)
        ).call
      end

      def build_notification_metadata(ongoing_work)
        {
          contractor_id: current_user.id,
          contractor_name: current_user.name || current_user.email,
          ongoing_work_id: ongoing_work.id,
          images_count: ongoing_work.images.count
        }
      end

      def render_create_success(ongoing_work)
        render_success(
          data: serialize_ongoing_work(ongoing_work),
          message: 'Ongoing work created successfully',
          status: :created
        )
      end

      def render_create_error(ongoing_work)
        render_error(
          message: 'Failed to create ongoing work',
          details: ongoing_work.errors.full_messages
        )
      end

      def update_ongoing_work
        update_params = {}
        update_params[:description] = params[:description] if params[:description].present?
        update_params[:work_date] = params[:work_date] if params[:work_date].present?

        return true if update_params.empty?

        @ongoing_work.update(update_params)
      end

      def render_update_success
        render_success(
          data: serialize_ongoing_work(@ongoing_work),
          message: 'Ongoing work updated successfully'
        )
      end

      def render_update_error
        render_error(
          message: 'Failed to update ongoing work',
          details: @ongoing_work.errors.full_messages
        )
      end
    end
  end
end
