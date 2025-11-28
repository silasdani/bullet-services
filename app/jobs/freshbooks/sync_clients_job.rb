# frozen_string_literal: true

module Freshbooks
  class SyncClientsJob < ApplicationJob
    queue_as :default

    retry_on FreshbooksError, wait: :exponentially_longer, attempts: 3
    discard_on ActiveRecord::RecordNotFound

    def perform(client_id = nil)
      clients_service = Freshbooks::Clients.new

      if client_id
        sync_single_client(clients_service, client_id)
      else
        sync_all_clients(clients_service)
      end
    end

    private

    def sync_single_client(clients_service, client_id)
      client_data = clients_service.get(client_id)
      return unless client_data

      create_or_update_client(client_data)
    end

    def sync_all_clients(clients_service)
      page = 1
      loop do
        result = clients_service.list(page: page, per_page: 100)
        clients = result[:clients]

        clients.each { |client_data| create_or_update_client(client_data) }

        break if page >= result[:pages]
        page += 1
      end
    end

    def create_or_update_client(client_data)
      FreshbooksClient.find_or_initialize_by(freshbooks_id: client_data['id']).tap do |client|
        client.assign_attributes(
          email: client_data['email'],
          first_name: client_data['fname'],
          last_name: client_data['lname'],
          organization: client_data['organization'],
          phone: client_data['phone'],
          address: client_data.dig('p_street'),
          city: client_data.dig('p_city'),
          province: client_data.dig('p_province'),
          postal_code: client_data.dig('p_code'),
          country: client_data.dig('p_country'),
          raw_data: client_data
        )
        client.save!
      end
    end
  end
end
