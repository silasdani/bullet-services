# frozen_string_literal: true

# FactoryBot configuration
FactoryBot.definition_file_paths = %w[spec/factories]
FactoryBot.find_definitions

# Set up test environment variables
ENV['WEBFLOW_TOKEN'] ||= 'test_token'
ENV['WEBFLOW_SITE_ID'] ||= 'test_site_id'
ENV['WEBFLOW_WRS_COLLECTION_ID'] ||= 'test_collection_id'
