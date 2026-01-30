# frozen_string_literal: true

module Api
  module V1
    class CheckInsController < BaseController
      before_action :set_check_in, only: [:show]

      def index
        authorize CheckIn

        collection = build_check_ins_collection
        paginated_collection = collection.page(@page).per(@per_page)
        serialized_data = serialize_check_ins_collection(paginated_collection)

        render_success(
          data: serialized_data,
          meta: pagination_meta(paginated_collection)
        )
      end

      def show
        authorize @check_in

        render_success(
          data: serialize_check_in(@check_in)
        )
      end

      # GET /api/v1/check_ins/active
      def active
        authorize CheckIn

        active_check_in = CheckIn.active_for(current_user, nil).includes(:window_schedule_repair).first

        if active_check_in
          render_success(data: serialize_check_in(active_check_in))
        else
          render_success(data: nil)
        end
      end

      private

      def build_check_ins_collection
        collection = policy_scope(CheckIn).includes(:user, :window_schedule_repair)
        collection = collection.ransack(params[:q]).result if params[:q].present?
        collection.order(timestamp: :desc)
      end

      def serialize_check_ins_collection(collection)
        collection.map { |check_in| serialize_check_in(check_in) }
      end

      def serialize_check_in(check_in)
        {
          id: check_in.id,
          action: check_in.action,
          window_schedule_repair_id: check_in.window_schedule_repair_id,
          window_schedule_repair_name: check_in.window_schedule_repair&.name || 'Unknown',
          timestamp: check_in.timestamp,
          address: check_in.address,
          latitude: check_in.latitude,
          longitude: check_in.longitude
        }
      end

      def set_check_in
        @check_in = CheckIn.find(params[:id])
      end
    end
  end
end
