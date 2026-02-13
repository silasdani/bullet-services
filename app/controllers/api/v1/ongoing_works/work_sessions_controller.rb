# frozen_string_literal: true

module Api
  module V1
    module OngoingWorks
      class WorkSessionsController < Api::V1::BaseController
        before_action :set_ongoing_work

        # GET /api/v1/ongoing_works/:ongoing_work_id/work_sessions
        def index
          authorize @ongoing_work.work_order, :show?

          sessions = @ongoing_work.work_sessions
                                  .includes(:user)
                                  .recent
                                  .page(@page)
                                  .per(@per_page)

          render_success(
            data: sessions.map { |ws| serialize_work_session(ws) },
            meta: pagination_meta(sessions)
          )
        end

        private

        def set_ongoing_work
          @ongoing_work = OngoingWork.find(params[:ongoing_work_id])
        end

        def serialize_work_session(session)
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
      end
    end
  end
end
