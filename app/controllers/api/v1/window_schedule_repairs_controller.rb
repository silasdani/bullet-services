# frozen_string_literal: true

module Api
  module V1
    class WindowScheduleRepairsController < Api::V1::BaseController
      include WrsCheckInCheckOut

      before_action :set_window_schedule_repair,
                    only: %i[show update restore check_in check_out assign unassign]

      def index
        authorize WindowScheduleRepair

        begin
          collection = build_wrs_collection

          paginated_collection = collection.page(@page).per(@per_page)
          serialized_data = serialize_wrs_collection(paginated_collection)

          render_success(
            data: serialized_data,
            meta: pagination_meta(paginated_collection)
          )
        rescue StandardError => e
          Rails.logger.error "Error in WRS index action: #{e.message}"
          Rails.logger.error e.backtrace.first(10).join("\n")
          render_error(message: 'Failed to load WRS list', status: :internal_server_error)
        end
      end

      def show
        return unless @window_schedule_repair

        authorize @window_schedule_repair

        render_success(
          data: WindowScheduleRepairSerializer.new(@window_schedule_repair, scope: current_user).serializable_hash
        )
      rescue Pundit::NotAuthorizedError
        raise
      rescue StandardError => e
        Rails.logger.error "Error in WRS show action: #{e.message}"
        Rails.logger.error e.backtrace.first(10).join("\n")
        render_error(message: 'Failed to load WRS details', status: :internal_server_error)
      end

      def create
        authorize WindowScheduleRepair

        service = Wrs::CreationService.new(
          user: current_user,
          params: window_schedule_repair_params
        )

        result = service.call

        if result[:success]
          render_success(
            data: WindowScheduleRepairSerializer.new(result[:wrs], scope: current_user).serializable_hash,
            message: 'WRS created successfully',
            status: :created
          )
        else
          render_error(
            message: 'Failed to create WRS',
            details: service.errors
          )
        end
      end

      def update
        authorize @window_schedule_repair

        service = Wrs::UpdateService.new(
          wrs: @window_schedule_repair,
          params: window_schedule_repair_params
        )

        result = service.call

        if result[:success]
          render_success(
            data: WindowScheduleRepairSerializer.new(result[:wrs], scope: current_user).serializable_hash,
            message: 'WRS updated successfully'
          )
        else
          render_error(
            message: 'Failed to update WRS',
            details: service.errors
          )
        end
      end

      def destroy
        window_schedule_repair = WindowScheduleRepair.find_by(id: params[:id])

        if window_schedule_repair.nil?
          render_error(message: 'WRS not found', status: :not_found)
          return
        end

        authorize window_schedule_repair

        window_schedule_repair.update(deleted_at: Time.current)

        render_success(
          data: {},
          message: 'WRS deleted successfully'
        )
      end

      def restore
        authorize @window_schedule_repair

        @window_schedule_repair.restore!

        render_success(
          data: WindowScheduleRepairSerializer.new(@window_schedule_repair, scope: current_user).serializable_hash,
          message: 'WRS restored successfully'
        )
      end

      def check_in
        authorize @window_schedule_repair, :show?
        authorize WorkSession, :check_in?
        service = build_check_in_service
        service.call
        if service.success?
          render_check_in_success(service)
        else
          render_error(message: 'Failed to check in',
                       details: service.errors)
        end
      end

      def check_out
        authorize @window_schedule_repair, :show?
        authorize WorkSession, :check_out?
        service = build_check_out_service
        service.call
        if service.success?
          render_check_out_success(service)
        else
          render_error(message: 'Failed to check out',
                       details: service.errors)
        end
      end

      def assign
        authorize @window_schedule_repair, :show?
        target_user = assignment_target_user

        unless allowed_to_manage_assignment_for?(target_user)
          return render_error(
            message: 'Not authorized to assign this user to a work order',
            status: :forbidden
          )
        end

        assignment = WorkOrderAssignment.find_or_initialize_by(user: target_user, work_order: @window_schedule_repair)
        assignment.assigned_by_user = current_user

        if assignment.save
          render_success(
            data: {
              user_id: target_user.id,
              work_order: WindowScheduleRepairSerializer.new(@window_schedule_repair, scope: current_user).serializable_hash,
              assigned: true
            },
            message: 'Successfully assigned to work order'
          )
        else
          render_error(
            message: 'Failed to assign to work order',
            details: assignment.errors.full_messages
          )
        end
      end

      def unassign
        authorize @window_schedule_repair, :show?
        target_user = assignment_target_user

        unless allowed_to_manage_assignment_for?(target_user)
          return render_error(
            message: 'Not authorized to unassign this user from a work order',
            status: :forbidden
          )
        end

        assignment = WorkOrderAssignment.find_by(user: target_user, work_order: @window_schedule_repair)
        assignment&.destroy

        render_success(
          data: {
            user_id: target_user.id,
            work_order_id: @window_schedule_repair.id,
            assigned: false
          },
          message: 'Successfully unassigned from work order'
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

      def build_wrs_collection
        # Policy scope is applied first to ensure contractors only see published WRS
        collection = policy_scope(WindowScheduleRepair)
                     .includes(:user, :building, :windows, windows: [:tools, { images_attachments: :blob }])
                     .order(created_at: :desc)

        # Apply Ransack filters if present (but policy scope restrictions remain)
        collection = collection.ransack(params[:q]).result if params[:q].present?

        collection
      end

      def serialize_wrs_collection(collection)
        collection.map do |wrs|
          WindowScheduleRepairSerializer.new(wrs, scope: current_user).serializable_hash
        rescue StandardError => e
          Rails.logger.error "Error serializing WRS #{wrs.id}: #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n")
          # Return minimal data instead of failing completely
          {
            id: wrs.id,
            name: wrs.name,
            error: 'Failed to load full details'
          }
        end
      end

      def set_window_schedule_repair
        @window_schedule_repair = find_wrs_for_action
        nil
      rescue ActiveRecord::RecordNotFound
        render_error(message: 'WRS not found', status: :not_found)
        nil
      rescue StandardError => e
        Rails.logger.error "Error loading WRS: #{e.message}"
        Rails.logger.error e.backtrace.first(10).join("\n")
        render_error(message: 'Failed to load WRS', status: :internal_server_error)
        nil
      end

      def find_wrs_for_action
        base = action_name == 'restore' ? WindowScheduleRepair.with_deleted : WindowScheduleRepair
        base.includes(:user, :building, :windows, windows: [:tools, { images_attachments: :blob }]).find(params[:id])
      end

      def window_schedule_repair_params
        if request.content_type&.include?('multipart/form-data')
          params.permit(*wrs_permitted_params)
        else
          params.require(:window_schedule_repair).permit(*wrs_permitted_params)
        end
      end

      def wrs_permitted_params
        [
          :name, :slug, :reference_number,
          :building_id, :flat_number, :details,
          :total_vat_excluded_price, :status, :status_color,
          { images: [],
            windows_attributes: [
              :id, :location, :image, :_destroy,
              { tools_attributes: %i[id name price _destroy] }
            ] }
        ]
      end
    end
  end
end
