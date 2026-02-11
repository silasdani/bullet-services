# frozen_string_literal: true

module Avo
  module Resources
    class WorkOrderDecision < Avo::BaseResource
      self.title = :decision
      self.includes = %i[work_order]
      self.search = {
        query: lambda {
          query.ransack(decision_cont: params[:q], client_email_cont: params[:q], m: 'or').result(distinct: false)
        }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :work_order, as: :belongs_to, required: true, filterable: true
        field :decision, as: :select, options: { approved: 'approved', rejected: 'rejected' }, required: true,
                         filterable: true
        field :decision_at, as: :date_time, required: true, sortable: true, filterable: true
        field :client_name, as: :text, hide_on: [:index]
        field :client_email, as: :text, hide_on: [:index]
        field :terms_accepted_at, as: :date_time, hide_on: [:index]
        field :terms_version, as: :text, hide_on: [:index]
        field :decision_metadata, as: :code, language: 'json', hide_on: [:index]
        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
        field :deleted_at, as: :date_time, hide_on: [:index]
      end
    end
  end
end
