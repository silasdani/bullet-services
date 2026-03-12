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

        active_entry = TimeEntry.clocked_in.for_user(current_user).includes(:work_order, :building).first

        if active_entry
          render_success(data: serialize_time_entry(active_entry))
        else
          render_success(data: nil)
        end
      end

      # POST /api/v1/time_entries/check_out — complete the current user's active TimeEntry (set ends_at, end coords).
      # Use this for contractor checkout; no work_order or ongoing_work in the path.
      def check_out
        authorize TimeEntry, :check_out?

        active_entry = TimeEntry.clocked_in.for_user(current_user).includes(:work_order, :ongoing_work).first
        unless active_entry
          return render_error(message: 'No active time entry to check out.', status: :unprocessable_entity)
        end

        service = TimeEntries::CheckOutService.new(
          user: current_user,
          work_order: active_entry.work_order,
          ongoing_work: active_entry.ongoing_work,
          latitude: params[:latitude],
          longitude: params[:longitude],
          address: params[:address]
        )
        service.call

        if service.success?
          render_success(
            data: serialize_time_entry(service.time_entry).merge(hours_worked: service.hours_worked),
            message: 'Checked out successfully',
            status: :created
          )
        else
          render_error(message: 'Failed to check out', details: service.errors, status: :unprocessable_entity)
        end
      end

      private

      def build_time_entries_collection
        collection = policy_scope(TimeEntry).includes(:user, :work_order, :building)
        collection = collection.for_building(params[:building_id]) if params[:building_id].present?
        collection = collection.ransack(params[:q]).result if params[:q].present?
        collection.order(starts_at: :desc)
      end

      def serialize_time_entries_collection(collection)
        collection.map { |entry| serialize_time_entry(entry) }
      end

      def serialize_time_entry(entry)
        {
          id: entry.id,
          building_id: entry.building_id,
          building_name: entry.building&.name,
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
          duration_minutes: entry.duration_minutes,
          auto_checkout: entry.auto_checkout
        }
      end

      def set_time_entry
        @time_entry = TimeEntry.find(params[:id])
      end
    end
  end
end
