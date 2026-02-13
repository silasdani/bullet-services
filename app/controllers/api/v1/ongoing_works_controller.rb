# frozen_string_literal: true

module Api
  module V1
    class OngoingWorksController < Api::V1::BaseController
      include OngoingWorkCheckInCheckOut

      before_action :set_work_order, only: %i[index create]
      before_action :set_ongoing_work, only: %i[show update destroy check_in check_out publish]

      # GET /api/v1/work_orders/:work_order_id/ongoing_works
      def index
        authorize @work_order, :show?

        ongoing_works = OngoingWork.where(work_order: @work_order)
                                   .includes(:user, work_sessions: [])
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
        authorize @ongoing_work.work_order, :show?

        render_success(
          data: serialize_ongoing_work(@ongoing_work)
        )
      end

      # POST /api/v1/work_orders/:work_order_id/ongoing_works
      def create
        authorize OngoingWork, :create?
        authorize @work_order, :show?

        ongoing_work = build_ongoing_work

        if ongoing_work.save
          attach_images(ongoing_work) if params[:images].present?
          create_work_update_notification(ongoing_work) unless ongoing_work.is_draft?
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

      # POST /api/v1/ongoing_works/:id/check_in
      def check_in
        authorize @ongoing_work.work_order, :show?
        authorize WorkSession, :check_in?

        service = build_ongoing_work_check_in_service
        service.call

        if service.success?
          render_check_in_success(service)
        else
          render_error(message: 'Failed to check in', details: service.errors)
        end
      end

      # POST /api/v1/ongoing_works/:id/check_out
      def check_out
        authorize @ongoing_work.work_order, :show?
        authorize WorkSession, :check_out?

        service = build_ongoing_work_check_out_service
        service.call

        if service.success?
          render_check_out_success(service)
        else
          render_error(message: 'Failed to check out', details: service.errors)
        end
      end

      # POST /api/v1/ongoing_works/:id/publish
      def publish
        authorize @ongoing_work

        @ongoing_work.publish!

        render_success(
          data: serialize_ongoing_work(@ongoing_work.reload),
          message: 'Ongoing work published successfully'
        )
      rescue StandardError => e
        Rails.logger.error "Error publishing ongoing work: #{e.message}"
        render_error(message: 'Failed to publish ongoing work', status: :unprocessable_entity)
      end

      private

      def set_work_order
        @work_order = WorkOrder.find(params[:work_order_id])
      end

      def set_ongoing_work
        @ongoing_work = OngoingWork.includes(work_sessions: []).find(params[:id])
      end

      def serialize_ongoing_work(ongoing_work)
        {
          id: ongoing_work.id,
          work_order_id: ongoing_work.work_order_id,
          description: ongoing_work.description,
          work_date: ongoing_work.work_date,
          user_id: ongoing_work.user_id,
          user_name: ongoing_work.user.name || ongoing_work.user.email,
          is_draft: ongoing_work.is_draft?,
          images: ongoing_work.image_urls,
          work_sessions: ongoing_work.work_sessions.recent.map { |ws| serialize_session(ws) },
          total_hours: ongoing_work.total_hours,
          checked_in: ongoing_work.checked_in?,
          created_at: ongoing_work.created_at,
          updated_at: ongoing_work.updated_at
        }
      end

      def serialize_session(session)
        {
          id: session.id,
          work_order_id: session.work_order_id,
          ongoing_work_id: session.ongoing_work_id,
          checked_in_at: session.checked_in_at,
          checked_out_at: session.checked_out_at,
          address: session.address,
          latitude: session.latitude,
          longitude: session.longitude,
          active: session.active?,
          duration_hours: session.duration_hours,
          duration_minutes: session.duration_minutes
        }
      end

      def build_work_update_message
        user_name = current_user.name || current_user.email
        "#{user_name} uploaded work photos for #{@work_order.name}"
      end

      def build_ongoing_work
        is_draft = params[:is_draft].nil? || ActiveModel::Type::Boolean.new.cast(params[:is_draft])

        OngoingWork.new(
          work_order: @work_order,
          user: current_user,
          description: params[:description],
          work_date: params[:work_date] || Date.current,
          is_draft: is_draft
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
        # Contractors and general contractors should not send work update notifications
        return if current_user.contractor? || current_user.general_contractor?

        Notifications::CreateService.new(
          user: @work_order&.user || ongoing_work.work_order.user,
          work_order: @work_order || ongoing_work.work_order,
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
        update_params[:description] = params[:description] if params.key?(:description)
        update_params[:work_date] = params[:work_date] if params[:work_date].present?
        update_params[:is_draft] = ActiveModel::Type::Boolean.new.cast(params[:is_draft]) if params.key?(:is_draft)

        # If only images were attached and no other params changed, that's a success
        return true if update_params.empty?

        @ongoing_work.update(update_params)
      end

      def render_update_success
        render_success(
          data: serialize_ongoing_work(@ongoing_work.reload),
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
