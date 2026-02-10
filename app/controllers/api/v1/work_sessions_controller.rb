# frozen_string_literal: true

module Api
  module V1
    class WorkSessionsController < Api::V1::BaseController
      before_action :set_work_session, only: [:show]

      def index
        authorize WorkSession

        collection = build_work_sessions_collection
        paginated_collection = collection.page(@page).per(@per_page)
        serialized_data = serialize_work_sessions_collection(paginated_collection)

        render_success(
          data: serialized_data,
          meta: pagination_meta(paginated_collection)
        )
      end

      def show
        authorize @work_session

        render_success(
          data: serialize_work_session(@work_session)
        )
      end

      # GET /api/v1/work_sessions/active
      def active
        authorize WorkSession

        active_session = WorkSession.active.for_user(current_user).includes(:work_order).first

        if active_session
          render_success(data: serialize_work_session(active_session))
        else
          render_success(data: nil)
        end
      end

      private

      def build_work_sessions_collection
        collection = policy_scope(WorkSession).includes(:user, :work_order)
        collection = collection.ransack(params[:q]).result if params[:q].present?
        collection.order(checked_in_at: :desc)
      end

      def serialize_work_sessions_collection(collection)
        collection.map { |session| serialize_work_session(session) }
      end

      def serialize_work_session(session)
        {
          id: session.id,
          work_order_id: session.work_order_id,
          work_order_name: session.work_order&.name || 'Unknown',
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

      def set_work_session
        @work_session = WorkSession.find(params[:id])
      end
    end
  end
end
