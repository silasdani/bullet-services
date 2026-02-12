# frozen_string_literal: true

module WorkOrders
  # Service for ensuring a local FreshBooks client record exists (no API calls).
  # The actual FreshBooks client creation/verification happens in background jobs.
  class FreshbooksClientEnsurer
    def initialize(email, first_name, last_name, building)
      @email = email
      @first_name = first_name
      @last_name = last_name
      @building = building
    end

    def call
      # Only check locally - no API calls during request
      existing_client = find_existing_client_locally
      return build_client_data_hash(existing_client) if existing_client

      # Create local record without FreshBooks ID - will be set by background job
      create_local_client_record
    end

    private

    attr_reader :email, :first_name, :last_name, :building

    def find_existing_client_locally
      FreshbooksClient.find_by(email: email)
    end

    def create_local_client_record
      client_record = FreshbooksClient.create!(
        freshbooks_id: nil,
        email: email,
        first_name: first_name,
        last_name: last_name,
        address: building&.street,
        city: 'London',
        postal_code: building&.zipcode,
        country: building&.country || 'UK'
      )

      Rails.logger.info(
        "Created local FreshbooksClient record: ID=#{client_record.id}, " \
        "email=#{email} (FreshBooks ID will be set by background job)"
      )

      build_client_data_hash(client_record)
    end

    def build_client_data_hash(client_record)
      {
        'id' => client_record.freshbooks_id,
        'clientid' => client_record.freshbooks_id,
        'email' => client_record.email,
        'fname' => client_record.first_name,
        'lname' => client_record.last_name
      }
    end
  end
end
