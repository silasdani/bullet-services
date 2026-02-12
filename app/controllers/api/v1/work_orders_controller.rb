# frozen_string_literal: true

module Api
  module V1
    class WorkOrdersController < Api::V1::BaseController
      include WorkOrderCheckInCheckOut
      include WorkOrderAssignmentHandling

      before_action :set_work_order,
                    only: %i[show update restore check_in check_out assign unassign publish unpublish]

      def index
        authorize WorkOrder

        collection = build_work_order_collection
        paginated_collection = collection.page(@page).per(@per_page)
        serialized_data = serialize_work_order_collection(paginated_collection)

        render_success(data: serialized_data, meta: pagination_meta(paginated_collection))
      rescue StandardError => e
        Rails.logger.error "Error in work orders index action: #{e.message}"
        Rails.logger.error e.backtrace.first(10).join("\n")
        render_error(message: 'Failed to load work orders list', status: :internal_server_error)
      end

      def show
        return unless @work_order

        authorize @work_order

        render_success(
          data: WorkOrderSerializer.new(@work_order, scope: current_user).serializable_hash
        )
      rescue Pundit::NotAuthorizedError
        raise
      rescue StandardError => e
        Rails.logger.error "Error in work order show action: #{e.message}"
        Rails.logger.error e.backtrace.first(10).join("\n")
        render_error(message: 'Failed to load work order details', status: :internal_server_error)
      end

      def create
        authorize WorkOrder

        service = WorkOrders::CreationService.new(
          user: current_user,
          params: work_order_params
        )

        result = service.call

        if result[:success]
          render_success(
            data: WorkOrderSerializer.new(result[:work_order], scope: current_user).serializable_hash,
            message: 'Work order created successfully',
            status: :created
          )
        else
          render_error(
            message: 'Failed to create work order',
            details: service.errors
          )
        end
      end

      def update
        authorize @work_order

        service = WorkOrders::UpdateService.new(
          work_order: @work_order,
          params: work_order_params,
          current_user: current_user
        )

        result = service.call

        if result[:success]
          render_success(
            data: WorkOrderSerializer.new(result[:work_order], scope: current_user).serializable_hash,
            message: 'Work order updated successfully'
          )
        else
          render_error(
            message: 'Failed to update work order',
            details: service.errors
          )
        end
      end

      def destroy
        work_order = WorkOrder.find_by(id: params[:id])

        if work_order.nil?
          render_error(message: 'Work order not found', status: :not_found)
          return
        end

        authorize work_order

        work_order.update(deleted_at: Time.current)

        render_success(
          data: {},
          message: 'Work order deleted successfully'
        )
      end

      def restore
        authorize @work_order

        @work_order.restore!

        render_success(
          data: WorkOrderSerializer.new(@work_order, scope: current_user).serializable_hash,
          message: 'Work order restored successfully'
        )
      end

      def check_in
        authorize @work_order, :show?
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
        authorize @work_order, :show?
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

      def publish
        authorize @work_order, :publish?

        @work_order.mark_as_published!

        render_success(
          data: WorkOrderSerializer.new(@work_order.reload, scope: current_user).serializable_hash,
          message: 'Work order published successfully'
        )
      rescue Pundit::NotAuthorizedError
        raise
      rescue StandardError => e
        Rails.logger.error "Error publishing work order: #{e.message}"
        render_error(message: 'Failed to publish work order', status: :unprocessable_entity)
      end

      def unpublish
        authorize @work_order, :publish?

        @work_order.mark_as_draft!

        render_success(
          data: WorkOrderSerializer.new(@work_order.reload, scope: current_user).serializable_hash,
          message: 'Work order unpublished successfully'
        )
      rescue Pundit::NotAuthorizedError
        raise
      rescue StandardError => e
        Rails.logger.error "Error unpublishing work order: #{e.message}"
        render_error(message: 'Failed to unpublish work order', status: :unprocessable_entity)
      end

      def assign
        authorize @work_order, :show?
        perform_assign
      end

      def unassign
        authorize @work_order, :show?
        perform_unassign
      end

      private

      def build_work_order_collection
        collection = policy_scope(WorkOrder)
                     .includes(:user, :building, :windows, windows: [:tools, { images_attachments: :blob }])
                     .order(created_at: :desc)

        # Filter by work_type if provided (e.g. ?work_type=wrs or ?work_type=general)
        collection = collection.where(work_type: params[:work_type]) if params[:work_type].present?

        # Apply Ransack filters if present (but policy scope restrictions remain)
        collection = collection.ransack(params[:q]).result if params[:q].present?

        collection
      end

      def serialize_work_order_collection(collection)
        collection.map do |wo|
          WorkOrderSerializer.new(wo, scope: current_user).serializable_hash
        rescue StandardError => e
          Rails.logger.error "Error serializing work order #{wo.id}: #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n")
          {
            id: wo.id,
            name: wo.name,
            error: 'Failed to load full details'
          }
        end
      end

      def set_work_order
        base = action_name == 'restore' ? WorkOrder.with_deleted : WorkOrder
        @work_order = base.includes(:user, :building, :windows, windows: [:tools, { images_attachments: :blob }])
                          .find(params[:id])
        nil
      rescue ActiveRecord::RecordNotFound
        render_error(message: 'Work order not found', status: :not_found)
        nil
      rescue StandardError => e
        Rails.logger.error "Error loading work order: #{e.message}"
        Rails.logger.error e.backtrace.first(10).join("\n")
        render_error(message: 'Failed to load work order', status: :internal_server_error)
        nil
      end

      def work_order_params
        permitted = [
          :name, :slug, :reference_number, :building_id, :flat_number, :details,
          :total_vat_excluded_price, :status, :status_color, :work_type,
          { images: [],
            windows_attributes: [:id, :location, :image, :_destroy,
                                 { tools_attributes: %i[id name price _destroy] }] }
        ]
        if request.content_type&.include?('multipart/form-data')
          params.permit(*permitted)
        else
          params.require(:work_order).permit(*permitted)
        end
      end
    end
  end
end
