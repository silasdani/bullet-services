# frozen_string_literal: true

module Api
  module V1
    class NotificationsController < Api::V1::BaseController
      before_action :set_notification, only: %i[show mark_read mark_unread]

      # GET /api/v1/notifications
      def index
        authorize Notification

        notifications = load_notifications
        notifications = filter_unread(notifications) if params[:unread_only] == 'true'

        render_success(
          data: serialize_notifications(notifications),
          meta: pagination_meta(notifications)
        )
      end

      # GET /api/v1/notifications/:id
      def show
        authorize @notification

        render_success(
          data: {
            id: @notification.id,
            notification_type: @notification.notification_type,
            title: @notification.title,
            message: @notification.message,
            read: @notification.read?,
            read_at: @notification.read_at,
            work_order_id: @notification.work_order_id,
            work_order_name: @notification.window_schedule_repair&.name,
            metadata: @notification.metadata,
            created_at: @notification.created_at,
            updated_at: @notification.updated_at
          }
        )
      end

      # POST /api/v1/notifications/:id/mark_read
      def mark_read
        authorize @notification
        @notification.mark_as_read!

        render_success(
          data: {
            id: @notification.id,
            read: @notification.read?,
            read_at: @notification.read_at
          },
          message: 'Notification marked as read'
        )
      end

      # POST /api/v1/notifications/:id/mark_unread
      def mark_unread
        authorize @notification
        @notification.mark_as_unread!

        render_success(
          data: {
            id: @notification.id,
            read: @notification.read?,
            read_at: @notification.read_at
          },
          message: 'Notification marked as unread'
        )
      end

      # POST /api/v1/notifications/mark_all_read
      def mark_all_read
        authorize Notification

        now = Time.current
        count = Notification.where(user: current_user, read_at: nil)
                            .update_all(read_at: now, updated_at: now)

        render_success(
          data: { count: count },
          message: "#{count} notifications marked as read"
        )
      end

      private

      def set_notification
        @notification = Notification.find(params[:id])
      end

      def load_notifications
        Notification.where(user: current_user)
                    .includes(:window_schedule_repair)
                    .order(created_at: :desc)
                    .page(@page)
                    .per(@per_page)
      end

      def filter_unread(notifications)
        notifications.unread
      end

      def serialize_notifications(notifications)
        notifications.map do |notif|
          {
            id: notif.id,
            notification_type: notif.notification_type,
            title: notif.title,
            message: notif.message,
            read: notif.read?,
            read_at: notif.read_at,
            work_order_id: notif.work_order_id,
            work_order_name: notif.window_schedule_repair&.name,
            metadata: notif.metadata,
            created_at: notif.created_at
          }
        end
      end
    end
  end
end
