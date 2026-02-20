# frozen_string_literal: true

module Avo
  module Resources
    class FreshbooksToken < Avo::BaseResource
      self.title = :business_id
      self.includes = []
      self.search = {
        query: -> { query.ransack(business_id_cont: params[:q], m: 'or').result(distinct: false) }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :reconnect_link, as: :text, only_on: [:show], as_html: true do
          if Rails.application.config.freshbooks[:client_id].present? && Rails.application.config.freshbooks[:redirect_uri].present?
            link_to 'Reconnect FreshBooks', main_app.freshbooks_reconnect_path,
                    class: 'text-blue-600 hover:underline', data: { turbo: false }
          else
            'Set FRESHBOOKS_CLIENT_ID and FRESHBOOKS_REDIRECT_URI to enable'
          end
        end
        field :business_id, as: :text, required: true, filterable: true
        field :user_freshbooks_id, as: :text, hide_on: [:index]
        field :token_expires_at, as: :date_time, required: true, sortable: true, filterable: true
        field :access_token, as: :textarea, hide_on: %i[index show]
        field :refresh_token, as: :textarea, hide_on: %i[index show]
        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
    end
  end
end
