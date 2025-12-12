# frozen_string_literal: true

module Api
  module V1
    class BuildingsController < Api::V1::BaseController
      before_action :set_building, only: %i[show update destroy window_schedule_repairs]

      def index
        authorize Building

        collection = policy_scope(Building)
                     .order(created_at: :desc)

        # Optional search/filter
        if params[:q].present?
          collection = collection.where('buildings.name ILIKE ? OR buildings.street ILIKE ? OR buildings.city ILIKE ?',
                                        "%#{params[:q]}%", "%#{params[:q]}%", "%#{params[:q]}%")
        end

        paginated_collection = collection.page(@page).per(@per_page)
        serialized_data = paginated_collection.map do |building|
          BuildingSerializer.new(building).serializable_hash
        end

        render_success(
          data: serialized_data,
          meta: pagination_meta(paginated_collection)
        )
      end

      def show
        authorize @building

        render_success(
          data: BuildingSerializer.new(@building).serializable_hash
        )
      end

      def create
        authorize Building

        # Find or create building by address fields (street, city, zipcode)
        building = Building.find_or_initialize_by(
          street: building_params[:street] || '',
          city: building_params[:city] || '',
          zipcode: building_params[:zipcode] || ''
        )

        # Update or set building fields
        building.name = building_params[:name] if building_params[:name].present?
        building.country = building_params[:country] || 'UK' if building.country.blank?

        unless building.save
          render_error(
            message: 'Failed to create building',
            details: building.errors.full_messages
          )
          return
        end

        render_success(
          data: BuildingSerializer.new(building.reload).serializable_hash,
          message: 'Building created successfully',
          status: :created
        )
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

        wrs_collection = @building.window_schedule_repairs
                                  .includes(:user, :windows, windows: %i[tools image_attachment])
                                  .order(created_at: :desc)

        paginated_collection = wrs_collection.page(@page).per(@per_page)
        serialized_data = paginated_collection.map do |wrs|
          WindowScheduleRepairSerializer.new(wrs).serializable_hash
        end

        render_success(
          data: serialized_data,
          meta: pagination_meta(paginated_collection)
        )
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
    end
  end
end
