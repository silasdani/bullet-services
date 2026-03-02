# frozen_string_literal: true

module Api
  module V1
    module OngoingWorks
      class TimeEntriesController < Api::V1::BaseController
        before_action :set_ongoing_work

        # GET /api/v1/ongoing_works/:ongoing_work_id/time_entries
        def index
          authorize @ongoing_work.work_order, :show?

          entries = @ongoing_work.time_entries
                                 .includes(:user)
                                 .recent
                                 .page(@page)
                                 .per(@per_page)

          render_success(
            data: entries.map { |te| serialize_time_entry(te) },
            meta: pagination_meta(entries)
          )
        end

        private

        def set_ongoing_work
          @ongoing_work = OngoingWork.find(params[:ongoing_work_id])
        end

        def serialize_time_entry(entry)
          {
            id: entry.id,
            work_order_id: entry.work_order_id,
            ongoing_work_id: entry.ongoing_work_id,
            starts_at: entry.starts_at,
            ends_at: entry.ends_at,
            start_address: entry.start_address,
            end_address: entry.end_address,
            start_lat: entry.start_lat,
            start_lng: entry.start_lng,
            end_lat: entry.end_lat,
            end_lng: entry.end_lng,
            active: entry.clocked_in?,
            duration_hours: entry.duration_hours,
            duration_minutes: entry.duration_minutes
          }
        end
      end
    end
  end
end
