# frozen_string_literal: true

module Api
  module V1
    class BuildingsController < Api::V1::BaseController
      include BuildingsWrsListing

      before_action :set_building, only: %i[show update destroy window_schedule_repairs assign unassign]

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
        if current_user.contractor?
          filter_buildings_with_wrs(collection)
        else
          collection
        end
      end

      def filter_buildings_with_wrs(collection)
        building_ids_with_wrs = WindowScheduleRepair
                                .where(is_draft: false)
                                .where(deleted_at: nil)
                                .where.not(building_id: nil)
                                .distinct
                                .pluck(:building_id)

        return collection.none if building_ids_with_wrs.empty?

        collection.where(id: building_ids_with_wrs)
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
        if current_user.contractor?
          return render_wrs_checked_in_elsewhere if contractor_checked_in_elsewhere?
          return render_wrs_not_assigned unless contractor_can_access_building_wrs?
        end
        wrs = wrs_collection_for_building
        paginated = wrs.page(@page).per(@per_page)
        render_success(data: serialize_wrs_page(paginated), meta: pagination_meta(paginated))
      end

      def assign
        authorize @building, :show?
        target_user = assignment_target_user

        unless allowed_to_manage_assignment_for?(target_user)
          return render_error(
            message: 'Not authorized to assign this user to a project',
            status: :forbidden
          )
        end

        assignment = BuildingAssignment.find_or_initialize_by(user: target_user, building: @building)
        assignment.assigned_by_user = current_user

        if assignment.save
          render_success(
            data: {
              user_id: target_user.id,
              building: BuildingSerializer.new(@building).serializable_hash,
              assigned: true
            },
            message: 'Successfully assigned to project'
          )
        else
          render_error(
            message: 'Failed to assign to project',
            details: assignment.errors.full_messages
          )
        end
      end

      def unassign
        authorize @building, :show?
        target_user = assignment_target_user

        unless allowed_to_manage_assignment_for?(target_user)
          return render_error(
            message: 'Not authorized to unassign this user from a project',
            status: :forbidden
          )
        end

        assignment = BuildingAssignment.find_by(user: target_user, building: @building)
        assignment&.destroy

        render_success(
          data: {
            user_id: target_user.id,
            building_id: @building.id,
            assigned: false
          },
          message: 'Successfully unassigned from project'
        )
      end

      private

      def assignment_target_user
        return current_user unless params[:user_id].present?
        return current_user unless current_user.admin?

        User.find(params[:user_id])
      end

      def allowed_to_manage_assignment_for?(target_user)
        return true if current_user.admin?
        return false unless current_user.contractor?

        target_user.id == current_user.id
      end

      def set_building
        @building = Building.includes(:window_schedule_repairs).find(params[:id])
      end

      def building_params
        params.require(:building).permit(
          :name, :street, :city, :country, :zipcode
        )
      end

      def should_show_all_buildings?(user)
        assigned_building_ids = BuildingAssignment.where(user_id: user.id).pluck(:building_id)

        return true if assigned_building_ids.empty?

        non_completed_wrs_count = WindowScheduleRepair
                                  .where(building_id: assigned_building_ids)
                                  .where(is_draft: false, is_archived: false)
                                  .contractor_visible_status
                                  .count

        non_completed_wrs_count.zero?
      end
    end
  end
end
