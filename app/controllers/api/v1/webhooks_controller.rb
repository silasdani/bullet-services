# frozen_string_literal: true

module Api
  module V1
    class WebhooksController < ActionController::API
      include WebflowWebhookHandling

      skip_before_action :verify_authenticity_token, raise: false

      # Webflow webhook for collection item published
      # Triggered when an item is published in Webflow
      def webflow_collection_item_published
        Rails.logger.info "Webflow Webhook Received: #{params.inspect}"

        return handle_unauthorized unless verify_webflow_webhook?

        process_webhook_payload
      rescue WebflowApiError => e
        handle_webflow_api_error(e)
      rescue StandardError => e
        handle_unexpected_error(e)
      end

      def process_webhook_payload
        payload = extract_payload
        return handle_missing_payload unless payload.present?

        items = extract_items(payload)
        return handle_missing_items unless items.present?

        results = process_items(items)
        render_webhook_response(results)
      end

      def handle_unauthorized
        render json: { error: 'Invalid webhook signature' }, status: :unauthorized
      end

      def extract_payload
        params[:payload]
      end

      def handle_missing_payload
        Rails.logger.error "Webflow Webhook: No payload found in params: #{params.inspect}"
        render json: { error: 'No payload provided in webhook' }, status: :bad_request
      end

      def extract_items(payload)
        items = payload[:items]
        return nil unless items.present? && items.is_a?(Array) && items.any?

        items
      end

      def handle_missing_items
        Rails.logger.error "Webflow Webhook: No items found in payload: #{params[:payload].inspect}"
        render json: { error: 'No items in payload' }, status: :bad_request
      end

      def process_items(items)
        items.map { |webflow_item| process_webflow_item(webflow_item) }
      end

      def render_webhook_response(results)
        if results.all? { |r| r[:success] }
          render_success_response(results)
        else
          render_partial_failure_response(results)
        end
      end

      def render_success_response(results)
        render json: {
          success: true,
          message: 'All items synced successfully',
          results: results
        }, status: :ok
      end

      def render_partial_failure_response(results)
        render json: {
          success: false,
          message: 'Some items failed to sync',
          results: results
        }, status: :unprocessable_content
      end

      def handle_webflow_api_error(error)
        Rails.logger.error "Webflow Webhook Error: #{error.message}"
        render json: {
          success: false,
          error: "Webflow API error: #{error.message}"
        }, status: :unprocessable_content
      end

      def handle_unexpected_error(error)
        Rails.logger.error "Webflow Webhook Unexpected Error: #{error.class} - #{error.message}"
        Rails.logger.error error.backtrace.first(5).join("\n")
        render json: {
          success: false,
          error: "Unexpected error: #{error.message}"
        }, status: :internal_server_error
      end
    end
  end
end

# Webflow collection_item_published Webhook Payload Structure:
#
# "triggerType" => "collection_item_published",
# "payload" => {
#   "items" => [
#     {
#       "id" => "68e6da253fab2e1905974866",
#       "siteId" => "618ffc83f3028ad35a166db8",
#       "workspaceId" => "686e45402f386a37da2a841b",
#       "collectionId" => "619692f4b6773922b32797f2",
#       "cmsLocaleId" => nil,
#       "lastPublished" => "2025-10-08T22:00:36.371Z",
#       "lastUpdated" => "2025-10-08T22:00:36.371Z",
#       "createdOn" => "2025-10-08T21:39:49.725Z",
#       "isArchived" => false,
#       "isDraft" => false,
#       "fieldData" => {
#         "accepted-declined" => "#FFA500",
#         "_noSearch" => false,
#         "total-incl-vat" => 345.6,
#         "total-exc-vat" => 288,
#         "grand-total" => 345.6,
#         "project-summary" => "1, one, 11",
#         "flat-number" => "111",
#         "name" => "1, one, 11 - 111",
#         "window-location" => "1",
#         "window-1-items-2" => "Easing and adjusting of sash window",
#         "window-1-items-prices-3" => "300",
#         "main-project-image" => {
#           "fileId" => "68e6dae5abbb2d252189d889",
#           "url" => "https://cdn.prod.website-files.com/.../image.jpeg",
#           "alt" => nil
#         },
#         "slug" => "1-one-11-111-afcd"
#       }
#     }
#   ]
# }
#
# Note: The published webhook sends items in an array, unlike the changed webhook
