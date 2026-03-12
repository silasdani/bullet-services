# frozen_string_literal: true

module Api
  module V1
    # rubocop:disable Metrics/ClassLength
    class OngoingWorksController < Api::V1::BaseController
      include OngoingWorkCheckInCheckOut

      before_action :set_work_order, only: %i[index create my_ongoing_work start_work]
      before_action :set_ongoing_work, only: %i[show update destroy check_in check_out publish]

      # GET /api/v1/work_orders/:work_order_id/ongoing_works
      def index
        authorize @work_order, :show?

        ongoing_works = OngoingWork.where(work_order: @work_order)
                                   .includes(:user, time_entries: [])
                                   .order(work_date: :desc, created_at: :desc)
                                   .page(@page)
                                   .per(@per_page)

        render_success(
          data: ongoing_works.map { |ow| serialize_ongoing_work(ow) },
          meta: pagination_meta(ongoing_works)
        )
      end

      # GET /api/v1/ongoing_works/:id
      def show
        authorize @ongoing_work.work_order, :show?

        render_success(
          data: serialize_ongoing_work(@ongoing_work)
        )
      end

      # GET /api/v1/work_orders/:id/my_ongoing_work — one ongoing work per user per work order (find or create)
      def my_ongoing_work
        authorize @work_order, :show?
        ensure_project_field_worker!

        ongoing_work = OngoingWork.find_or_initialize_by(work_order_id: @work_order.id)
        if ongoing_work.new_record?
          ongoing_work.user_id = current_user.id
          ongoing_work.work_date = params[:work_date].presence&.then { |d| Time.zone.parse(d) } || Date.current
          ongoing_work.is_draft = true
          ongoing_work.save!
        end
        ongoing_work = OngoingWork.includes(:user, time_entries: []).find(ongoing_work.id)

        render_success(data: serialize_ongoing_work(ongoing_work))
      end

      # POST /api/v1/work_orders/:id/start_work — find or create ongoing_work + check in (one tap for contractors)
      def start_work
        authorize @work_order, :show?
        authorize TimeEntry, :check_in?

        ongoing_work = find_or_create_my_ongoing_work
        @ongoing_work = ongoing_work

        service = build_ongoing_work_check_in_service
        service.call

        if service.success?
          render_success(
            data: {
              ongoing_work: serialize_ongoing_work(ongoing_work.reload),
              time_entry: time_entry_payload(service.time_entry)
            },
            message: 'Work started',
            status: :created
          )
        else
          render_error(message: 'Failed to start work', details: service.errors)
        end
      end

      # POST /api/v1/work_orders/:work_order_id/ongoing_works — find or create one per user per work order
      def create
        ensure_project_field_worker!
        authorize @work_order, :show?

        ongoing_work = OngoingWork.find_or_initialize_by(
          work_order_id: @work_order.id,
          user_id: current_user.id
        )
        if ongoing_work.new_record?
          ongoing_work.assign_attributes(
            work_date: params[:work_date].presence&.then { |d| Time.zone.parse(d) } || Date.current,
            description: params[:description],
            is_draft: params[:is_draft].nil? || ActiveModel::Type::Boolean.new.cast(params[:is_draft])
          )
          ongoing_work.save!
          attach_images(ongoing_work) if params[:images].present?
          create_work_update_notification(ongoing_work) unless ongoing_work.is_draft?
        end
        ongoing_work = OngoingWork.includes(:user, time_entries: []).find(ongoing_work.id)

        render_success(
          data: serialize_ongoing_work(ongoing_work),
          message: 'Ongoing work created successfully',
          status: :created
        )
      end

      # PATCH /api/v1/ongoing_works/:id
      def update
        authorize @ongoing_work

        # Attach images before update so validation can check them
        attach_images(@ongoing_work) if params[:images].present?

        if update_ongoing_work
          render_update_success
        else
          render_update_error
        end
      end

      # DELETE /api/v1/ongoing_works/:id
      def destroy
        authorize @ongoing_work
        @ongoing_work.destroy

        render_success(
          data: {},
          message: 'Ongoing work deleted successfully'
        )
      end

      # POST /api/v1/ongoing_works/:id/check_in
      def check_in
        authorize @ongoing_work.work_order, :show?
        authorize TimeEntry, :check_in?

        service = build_ongoing_work_check_in_service
        service.call

        if service.success?
          render_check_in_success(service)
        else
          render_error(message: 'Failed to check in', details: service.errors)
        end
      end

      # POST /api/v1/ongoing_works/:id/check_out
      def check_out
        authorize @ongoing_work.work_order, :show?
        authorize TimeEntry, :check_out?

        service = build_ongoing_work_check_out_service
        service.call

        if service.success?
          render_check_out_success(service)
        else
          render_error(message: 'Failed to check out', details: service.errors)
        end
      end

      # POST /api/v1/ongoing_works/:id/publish
      def publish
        authorize @ongoing_work

        if @ongoing_work.publish!
          render_success(
            data: serialize_ongoing_work(@ongoing_work.reload),
            message: 'Ongoing work published successfully'
          )
        else
          render_error(
            message: 'Failed to publish ongoing work',
            details: @ongoing_work.errors.full_messages,
            status: :unprocessable_entity
          )
        end
      rescue StandardError => e
        Rails.logger.error "Error publishing ongoing work: #{e.message}"
        render_error(message: 'Failed to publish ongoing work', status: :unprocessable_entity)
      end

      private

      def set_work_order
        @work_order = WorkOrder.find(params[:work_order_id] || params[:id])
      end

      def find_or_create_my_ongoing_work
        ensure_project_field_worker!

        ongoing_work = OngoingWork.find_or_initialize_by(work_order_id: @work_order.id)
        if ongoing_work.new_record?
          ongoing_work.user_id = current_user.id
          ongoing_work.work_date = params[:work_date].presence&.then { |d| Time.zone.parse(d) } || Date.current
          ongoing_work.is_draft = true
          ongoing_work.save!
        end
        OngoingWork.includes(:user, time_entries: []).find(ongoing_work.id)
      end

      def ensure_project_field_worker!
        building = @work_order&.building
        return unless building

        resolver = ProjectRoleResolver.new(user: current_user, building: building)
        return if resolver.can_check_in?

        raise Pundit::NotAuthorizedError, 'You do not have permission to start work on this project'
      end

      def set_ongoing_work
        @ongoing_work = OngoingWork.includes(time_entries: []).find(params[:id])
      end

      def serialize_ongoing_work(ongoing_work)
        entries = ongoing_work.time_entries.reload.recent
        windows = windows_payload_for(ongoing_work)
        windows_with_before_after = decorate_windows_with_before_after(windows, ongoing_work)
        {
          id: ongoing_work.id,
          work_order_id: ongoing_work.work_order_id,
          description: ongoing_work.description,
          work_date: ongoing_work.work_date,
          user_id: ongoing_work.user_id,
          user_name: ongoing_work.user.name || ongoing_work.user.email,
          is_draft: ongoing_work.is_draft?,
          images: ongoing_work.image_urls,
          time_entries: entries.map { |te| serialize_time_entry(te) },
          total_hours: ongoing_work.total_hours,
          checked_in: ongoing_work.checked_in?,
          windows: windows_with_before_after,
          created_at: ongoing_work.created_at,
          updated_at: ongoing_work.updated_at
        }
      end

      def serialize_time_entry(entry)
        {
          id: entry.id,
          work_order_id: entry.work_order_id,
          ongoing_work_id: entry.ongoing_work_id,
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
          duration_minutes: entry.duration_minutes
        }
      end

      def build_work_update_message
        user_name = current_user.name || current_user.email
        "#{user_name} uploaded work photos for #{@work_order.name}"
      end

      def build_ongoing_work
        is_draft = params[:is_draft].nil? || ActiveModel::Type::Boolean.new.cast(params[:is_draft])

        OngoingWork.new(
          work_order: @work_order,
          user: current_user,
          description: params[:description],
          work_date: params[:work_date] || Date.current,
          is_draft: is_draft
        )
      end

      def attach_images(ongoing_work)
        images_array = if params[:images].is_a?(Hash) || params[:images].is_a?(ActionController::Parameters)
                         params[:images].values
                       else
                         Array(params[:images])
                       end
        return unless images_array.any?

        uploader_id = current_user&.id
        images_array.each do |file|
          ongoing_work.images.attach(file)
          next unless uploader_id

          # has_many_attached.attach returns the proxy, not the new attachment; get the one we just added
          att = ongoing_work.images.attachments.reorder(created_at: :desc).first
          next unless att

          att.blob.update(metadata: (att.blob.metadata || {}).merge('uploaded_by_user_id' => uploader_id))
        end
      end

      def create_work_update_notification(ongoing_work)
        # Contractors and general contractors should not send work update notifications
        return if current_user.contractor? || current_user.general_contractor?

        Notifications::CreateService.new(
          user: @work_order&.user || ongoing_work.work_order.user,
          work_order: @work_order || ongoing_work.work_order,
          notification_type: :work_update,
          title: 'Work Update',
          message: build_work_update_message,
          metadata: build_notification_metadata(ongoing_work)
        ).call
      end

      def build_notification_metadata(ongoing_work)
        windows = windows_payload_for(ongoing_work)
        {
          contractor_id: current_user.id,
          contractor_name: current_user.name || current_user.email,
          ongoing_work_id: ongoing_work.id,
          images_count: ongoing_work.images.count,
          windows: windows,
          windows_json: windows.to_json
        }
      end

      def windows_payload_for(ongoing_work)
        work_order = ongoing_work.work_order
        return [] unless work_order

        WorkOrderSerializer
          .new(work_order, scope: current_user)
          .serializable_hash[:windows] || []
      rescue StandardError => e
        Rails.logger.error "Error building windows payload for ongoing work #{ongoing_work.id}: #{e.message}"
        []
      end

      def render_create_success(ongoing_work)
        render_success(
          data: serialize_ongoing_work(ongoing_work),
          message: 'Ongoing work created successfully',
          status: :created
        )
      end

      def render_create_error(ongoing_work)
        render_error(
          message: 'Failed to create ongoing work',
          details: ongoing_work.errors.full_messages
        )
      end

      def update_ongoing_work
        update_params = {}
        update_params[:description] = params[:description] if params.key?(:description)
        update_params[:work_date] = params[:work_date] if params[:work_date].present?
        update_params[:is_draft] = ActiveModel::Type::Boolean.new.cast(params[:is_draft]) if params.key?(:is_draft)

        # If only images were attached and no other params changed, that's a success
        return true if update_params.empty?

        @ongoing_work.update(update_params)
      end

      def render_update_success
        render_success(
          data: serialize_ongoing_work(@ongoing_work.reload),
          message: 'Ongoing work updated successfully'
        )
      end

      def render_update_error
        render_error(
          message: 'Failed to update ongoing work',
          details: @ongoing_work.errors.full_messages
        )
      end

      # For each work order window, expose:
      # - before_images: source WRS/window images
      # - after_images: images uploaded on this ongoing_work that are tagged for the window
      #
      # Tagging convention: client sends filenames containing "window_{id}_",
      # e.g. "window_12_1700000000.jpg". We group attachments by that id.
      def decorate_windows_with_before_after(windows, ongoing_work)
        return windows if windows.blank?

        after_by_window_id = window_after_images_for(ongoing_work)

        # Fallback: if there is exactly one window and we have images attached to the ongoing work
        # but none of them are tagged with a window id, treat all images as "after" for that window.
        if after_by_window_id.empty? && windows.size == 1 && ongoing_work.images.attached?
          after_entries = ongoing_work.image_entries.map { |e| e.merge(created_at: e[:created_at]&.iso8601) }
          after_entries = enrich_image_entries_with_uploader_names(after_entries)
          return windows.map.with_index do |win, idx|
            before = before_image_entries_for(win)
            win.merge(
              before_images: before,
              after_images: idx.zero? ? after_entries : []
            )
          end
        end

        windows.map do |win|
          window_id = win[:id]
          before = before_image_entries_for(win)
          after = window_id ? enrich_image_entries_with_uploader_names(Array(after_by_window_id[window_id]).compact) : []

          win.merge(
            before_images: before,
            after_images: after
          )
        end
      rescue StandardError => e
        Rails.logger.error "Error decorating windows with before/after for ongoing work #{ongoing_work.id}: #{e.message}"
        windows
      end

      def before_image_entries_for(win)
        if win.key?(:effective_image_entries) && win[:effective_image_entries].respond_to?(:to_a)
          entries = Array(win[:effective_image_entries]).compact
          return entries if entries.any?
        end
        # Fallback: build entries from URL arrays (no timestamp)
        urls = if win.key?(:effective_image_urls) && win[:effective_image_urls].respond_to?(:to_a)
                 Array(win[:effective_image_urls]).compact
               elsif win.key?(:images) && win[:images].respond_to?(:to_a)
                 Array(win[:images]).compact
               else
                 []
               end
        urls.map { |u| { url: u, created_at: nil } }
      end

      def enrich_image_entries_with_uploader_names(entries)
        return entries if entries.blank?

        user_ids = entries.filter_map { |e| e[:uploaded_by_user_id] }.uniq
        if user_ids.empty?
          return entries.map { |e| e.merge(uploaded_by: nil, uploaded_by_avatar_url: nil) }
        end

        url_helpers = Rails.application.routes.url_helpers
        users_data = User.where(id: user_ids).includes(image_attachment: :blob).each_with_object({}) do |u, h|
          h[u.id] = {
            name: (u.name.presence || u.email).to_s,
            avatar_url: u.image.attached? ? url_helpers.rails_blob_path(u.image, only_path: true) : nil
          }
        end

        entries.map do |e|
          uid = e[:uploaded_by_user_id]
          data = users_data[uid]
          e.merge(
            uploaded_by: data&.dig(:name).presence || 'Unknown',
            uploaded_by_avatar_url: data&.dig(:avatar_url)
          )
        end
      end

      def window_after_images_for(ongoing_work)
        return {} unless ongoing_work.images.attached?

        url_helpers = Rails.application.routes.url_helpers
        groups = Hash.new { |h, k| h[k] = [] }

        ongoing_work.images.each do |img|
          filename = img.blob.filename.to_s
          # Extract window id from filename.
          # Supported patterns (to be tolerant with frontend naming):
          # - "window_{id}_..."  (e.g. "window_12_1700000000.jpg")
          # - "window-{id}-..."  (e.g. "window-12-1700000000.jpg")
          # - "window_{id}..."   (no extra underscore)
          # - "window-{id}..."   (no extra dash)
          window_id_str =
            filename[/window_(\d+)_/, 1] ||
            filename[/window-(\d+)-/, 1] ||
            filename[/window_(\d+)/, 1] ||
            filename[/window-(\d+)/, 1]
          next unless window_id_str

          window_id = window_id_str.to_i
          next if window_id.zero?

          uploader_id = img.blob.metadata&.dig('uploaded_by_user_id')
          url = url_helpers.rails_blob_path(img, only_path: true)
          groups[window_id] << { url: url, created_at: img.created_at&.iso8601, uploaded_by_user_id: uploader_id }
        rescue StandardError => e
          Rails.logger.error "Error grouping ongoing work image #{img.id} for ongoing work #{ongoing_work.id}: #{e.message}"
        end

        groups
      end
    end
    # rubocop:enable Metrics/ClassLength, Metrics/AbcSize
  end
end
