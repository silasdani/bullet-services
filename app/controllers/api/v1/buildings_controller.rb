# frozen_string_literal: true

module Api
  module V1
    class BuildingsController < Api::V1::BaseController
      include BuildingsWrsListing

      before_action :set_building, only: %i[show update destroy window_schedule_repairs]

      def index
        authorize Building

        collection = build_buildings_collection
        paginated_collection = collection.page(@page).per(@per_page)
        serialized_data = serialize_buildings(paginated_collection)

        render_success(
          data: serialized_data,
          meta: pagination_meta(paginated_collection)
        )
      end

      def build_buildings_collection
        collection = policy_scope(Building).order(created_at: :desc)
        collection = apply_search_filter(collection)
        if current_user.contractor? || current_user.general_contractor?
          filter_buildings_with_wrs(collection)
        else
          collection
        end
      end

      def filter_buildings_with_wrs(collection)
        # General contractors see all projects; contractors see only assigned (or all when unassigned)
        assigned_work_order_ids = if current_user.general_contractor?
                                    []
                                  else
                                    WorkOrderAssignment.where(user_id: current_user.id).pluck(:work_order_id)
                                  end

        if assigned_work_order_ids.empty?
          # No assignments: show all buildings with active work orders
          building_ids_with_wrs = WindowScheduleRepair
                                  .where(is_draft: false)
                                  .where(deleted_at: nil)
                                  .where.not(building_id: nil)
                                  .contractor_visible_status
                                  .distinct
                                  .pluck(:building_id)
          return collection.none if building_ids_with_wrs.empty?

          return collection.where(id: building_ids_with_wrs)
        end

        # Has assignments: only show buildings with assigned work orders
        building_ids = WindowScheduleRepair
                       .where(id: assigned_work_order_ids)
                       .where(is_draft: false, deleted_at: nil)
                       .contractor_visible_status
                       .distinct
                       .pluck(:building_id)

        return collection.none if building_ids.empty?

        collection.where(id: building_ids)
      rescue StandardError => e
        Rails.logger.error "Error filtering buildings with WRS: #{e.message}"
        collection
      end

      def apply_search_filter(collection)
        return collection unless params[:q].present?

        search_term = "%#{params[:q]}%"
        collection.where('buildings.name ILIKE ? OR buildings.street ILIKE ? OR buildings.city ILIKE ?',
                         search_term, search_term, search_term)
      end

      def serialize_buildings(buildings)
        buildings.map { |building| BuildingSerializer.new(building).serializable_hash }
      end

      def show
        authorize @building

        render_success(
          data: BuildingSerializer.new(@building).serializable_hash
        )
      end

      def create
        authorize Building

        building = find_or_initialize_building
        update_building_fields(building)

        if building.save
          render_success(
            data: BuildingSerializer.new(building.reload).serializable_hash,
            message: 'Building created successfully',
            status: :created
          )
        else
          render_error(
            message: 'Failed to create building',
            details: building.errors.full_messages
          )
        end
      end

      def find_or_initialize_building
        Building.find_or_initialize_by(
          street: building_params[:street] || '',
          city: building_params[:city] || '',
          zipcode: building_params[:zipcode] || ''
        )
      end

      def update_building_fields(building)
        building.name = building_params[:name] if building_params[:name].present?
        building.country = building_params[:country] || 'UK' if building.country.blank?
      end

      def update
        authorize @building

        # Update building fields directly
        if @building.update(building_params)
          render_success(
            data: BuildingSerializer.new(@building.reload).serializable_hash,
            message: 'Building updated successfully'
          )
        else
          render_error(
            message: 'Failed to update building',
            details: @building.errors.full_messages
          )
        end
      end

      def destroy
        authorize @building

        @building.update(deleted_at: Time.current)

        render_success(
          data: {},
          message: 'Building deleted successfully'
        )
      end

      def window_schedule_repairs
        authorize @building, :show?
        if current_user.contractor? || current_user.general_contractor?
          return render_wrs_checked_in_elsewhere if contractor_checked_in_elsewhere?
          return render_wrs_not_assigned unless contractor_can_access_building_wrs?
        end
        wrs = wrs_collection_for_building
        paginated = wrs.page(@page).per(@per_page)
        render_success(data: serialize_wrs_page(paginated), meta: pagination_meta(paginated))
      end

      private

      def set_building
        @building = Building.includes(:window_schedule_repairs).find(params[:id])
      end

      def building_params
        params.require(:building).permit(
          :name, :street, :city, :country, :zipcode
        )
      end

      def should_show_all_work_orders?(user)
        assigned_work_order_ids = WorkOrderAssignment.where(user_id: user.id).pluck(:work_order_id)

        return true if assigned_work_order_ids.empty?

        non_completed_count = WindowScheduleRepair
                              .where(id: assigned_work_order_ids)
                              .where(is_draft: false, is_archived: false)
                              .contractor_visible_status
                              .count

        non_completed_count.zero?
      end
    end
  end
end
