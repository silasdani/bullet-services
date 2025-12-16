# frozen_string_literal: true

module Wrs
  # Service for ensuring a FreshBooks client exists for a WRS decision
  class FreshbooksClientEnsurer
    def initialize(email, first_name, last_name, building)
      @email = email
      @first_name = first_name
      @last_name = last_name
      @building = building
    end

    def call
      clients_client = Freshbooks::Clients.new

      existing_client = find_existing_client(clients_client)
      return existing_client if existing_client

      create_new_client(clients_client)
    end

    private

    attr_reader :email, :first_name, :last_name, :building

    def find_existing_client(clients_client)
      fb_client_record = FreshbooksClient.find_by(email: email)
      return nil unless fb_client_record

      clients_client.get(fb_client_record.freshbooks_id)
    end

    def create_new_client(clients_client)
      created = clients_client.create(build_client_creation_params)
      fb_id = extract_client_id(created)
      client_record = create_local_client_record(created, fb_id)

      Rails.logger.info(
        "Created FreshbooksClient record: ID=#{client_record.id}, " \
        "freshbooks_id=#{fb_id}, email=#{email}"
      )

      created
    end

    def build_client_creation_params
      {
        email: email,
        first_name: first_name,
        last_name: last_name,
        organization: nil,
        phone: nil,
        address: building&.street,
        city: 'London',
        province: nil,
        postal_code: building&.zipcode,
        country: building&.country || 'UK'
      }
    end

    def extract_client_id(created)
      created['id'] || created['clientid']
    end

    def create_local_client_record(created, fb_id)
      FreshbooksClient.create!(
        freshbooks_id: fb_id,
        email: email,
        first_name: first_name,
        last_name: last_name,
        address: building&.street,
        city: 'London',
        postal_code: building&.zipcode,
        country: building&.country || 'UK',
        raw_data: created
      )
    end
  end
end
