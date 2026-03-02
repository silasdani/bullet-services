# frozen_string_literal: true

module Api
  module V1
    class TimeEntriesController < Api::V1::BaseController
      before_action :set_time_entry, only: [:show]

      def index
        authorize TimeEntry

        collection = build_time_entries_collection
        paginated_collection = collection.page(@page).per(@per_page)
        serialized_data = serialize_time_entries_collection(paginated_collection)

        render_success(
          data: serialized_data,
          meta: pagination_meta(paginated_collection)
        )
      end

      def show
        authorize @time_entry

        render_success(
          data: serialize_time_entry(@time_entry)
        )
      end

      # GET /api/v1/time_entries/active
      def active
        authorize TimeEntry

        active_entry = TimeEntry.clocked_in.for_user(current_user).includes(:work_order).first

        if active_entry
          render_success(data: serialize_time_entry(active_entry))
        else
          render_success(data: nil)
        end
      end

      private

      def build_time_entries_collection
        collection = policy_scope(TimeEntry).includes(:user, :work_order)
        collection = collection.ransack(params[:q]).result if params[:q].present?
        collection.order(starts_at: :desc)
      end

      def serialize_time_entries_collection(collection)
        collection.map { |entry| serialize_time_entry(entry) }
      end

      def serialize_time_entry(entry)
        {
          id: entry.id,
          work_order_id: entry.work_order_id,
          ongoing_work_id: entry.ongoing_work_id,
          work_order_name: entry.work_order&.name || 'Unknown',
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

      def set_time_entry
        @time_entry = TimeEntry.find(params[:id])
      end
    end
  end
end
