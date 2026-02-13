# frozen_string_literal: true

module Api
  module V1
    class BuildingsController < Api::V1::BaseController
      include BuildingsWorkOrderListing

      before_action :set_building, only: %i[show update destroy work_orders]

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
          filter_buildings_with_work_orders(collection)
        else
          collection
        end
      end

      def filter_buildings_with_work_orders(collection)
        assigned_work_order_ids = assigned_work_order_ids_for_filter
        building_ids = building_ids_from_work_order_filter(assigned_work_order_ids)

        return collection.none if building_ids.empty?

        collection.where(id: building_ids)
      rescue StandardError => e
        Rails.logger.error "Error filtering buildings with work orders: #{e.message}"
        collection
      end

      def assigned_work_order_ids_for_filter
        return [] if current_user.general_contractor?

        WorkOrderAssignment.where(user_id: current_user.id).pluck(:work_order_id)
      end

      def building_ids_from_work_order_filter(assigned_work_order_ids)
        scope = WorkOrder
                .where(is_draft: false, deleted_at: nil)
                .contractor_visible_status

        scope = if assigned_work_order_ids.empty?
                  scope.where.not(building_id: nil)
                else
                  scope.where(id: assigned_work_order_ids)
                end
        scope.distinct.pluck(:building_id)
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

      def work_orders
        authorize @building, :show?
        return if work_order_access_denied?

        render_paginated_work_orders
      end

      def render_paginated_work_orders
        collection = work_order_collection_for_building.page(@page).per(@per_page)
        render_success(data: serialize_work_order_page(collection), meta: pagination_meta(collection))
      end

      def work_order_access_denied?
        if current_user.contractor? || current_user.general_contractor?
          return render_work_order_checked_in_elsewhere if contractor_checked_in_elsewhere?
          return render_work_order_not_assigned unless contractor_can_access_building_work_orders?
        end
        if current_user.supervisor? && !supervisor_can_access_building_work_orders?
          return render_work_order_not_assigned
        end

        false
      end

      private

      def set_building
        @building = Building.includes(:work_orders).find(params[:id])
      end

      def building_params
        params.require(:building).permit(
          :name, :street, :city, :country, :zipcode
        )
      end

      def should_show_all_work_orders?(user)
        assigned_work_order_ids = WorkOrderAssignment.where(user_id: user.id).pluck(:work_order_id)

        return true if assigned_work_order_ids.empty?

        non_completed_count = WorkOrder
                              .where(id: assigned_work_order_ids)
                              .where(is_draft: false, is_archived: false)
                              .contractor_visible_status
                              .count

        non_completed_count.zero?
      end
    end
  end
end
