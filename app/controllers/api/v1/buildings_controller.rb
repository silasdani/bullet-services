# frozen_string_literal: true

module Api
  module V1
    class BuildingsController < Api::V1::BaseController
      include BuildingsWorkOrderListing

      before_action :set_building, only: %i[show update destroy work_orders schedule_of_condition]

      def assigned
        authorize Building
        collection = assigned_buildings_collection
        serialized_data = serialize_buildings(collection)
        render_success(data: serialized_data)
      end

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
        collection
      end

      def assigned_buildings_collection
        building_ids = Assignment.where(user_id: current_user.id).pluck(:building_id)
        return Building.none if building_ids.empty?

        visible = WorkOrder.where(building_id: building_ids, is_draft: false, deleted_at: nil)
                           .contractor_visible_status
                           .select(:building_id)
        Building.where(id: building_ids).where(id: visible).distinct.order(name: :asc)
      end

      def apply_search_filter(collection)
        return collection unless params[:q].present?

        search_term = "%#{params[:q]}%"
        collection.where('buildings.name ILIKE ? OR buildings.street ILIKE ? OR buildings.city ILIKE ?',
                         search_term, search_term, search_term)
      end

      def serialize_buildings(buildings)
        buildings.map { |building| BuildingSerializer.new(building, scope: current_user).serializable_hash }
      end

      def show
        authorize @building

        render_success(
          data: BuildingSerializer.new(@building, scope: current_user).serializable_hash
        )
      end

      def create
        authorize Building

        building = find_or_initialize_building
        update_building_fields(building)

        if building.save
          render_success(
            data: BuildingSerializer.new(building.reload, scope: current_user).serializable_hash,
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
            data: BuildingSerializer.new(@building.reload, scope: current_user).serializable_hash,
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

      def schedule_of_condition
        authorize @building, :update?

        if schedule_of_condition_updated?
          @building.reload
          @building.schedule_of_condition_images.reload if @building.schedule_of_condition_images.attached?
          render_success(
            data: BuildingSerializer.new(@building, scope: current_user).serializable_hash,
            message: 'Schedule of Condition updated successfully'
          )
        else
          render_error(
            message: 'Failed to update Schedule of Condition',
            details: @building.errors.full_messages
          )
        end
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
        @building = Building.includes(:work_orders, schedule_of_condition_images_attachments: :blob).find(params[:id])
      end

      def building_params
        params.require(:building).permit(
          :name, :street, :city, :country, :zipcode,
          :schedule_of_condition_notes,
          :purge_all_images,
          purge_image_ids: [],
          schedule_of_condition_images: []
        )
      end

      def schedule_of_condition_updated?
        Buildings::UpdateScheduleOfConditionService.new(
          building: @building,
          params: building_params.to_h
        ).call
      end

      def should_show_all_work_orders?(user)
        building_ids = Assignment.where(user_id: user.id).pluck(:building_id)
        return true if building_ids.empty?

        non_completed_count = WorkOrder
                              .where(building_id: building_ids)
                              .where(is_draft: false, is_archived: false)
                              .contractor_visible_status
                              .count

        non_completed_count.zero?
      end
    end
  end
end
