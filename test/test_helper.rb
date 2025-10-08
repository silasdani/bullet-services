ENV["RAILS_ENV"] ||= "test"

# Set dummy environment variables for test environment
ENV["WEBFLOW_TOKEN"] ||= "test_token"
ENV["WEBFLOW_SITE_ID"] ||= "test_site_id"
ENV["WEBFLOW_WRS_COLLECTION_ID"] ||= "test_collection_id"

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # Disabled due to Ruby 3.4.4 segfault with PostgreSQL
    # parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
