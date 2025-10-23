# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

# Set dummy environment variables for test environment
ENV['WEBFLOW_TOKEN'] ||= 'test_token'
ENV['WEBFLOW_SITE_ID'] ||= 'test_site_id'
ENV['WEBFLOW_WRS_COLLECTION_ID'] ||= 'test_collection_id'

require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/mock'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # Disabled due to Ruby 3.4.4 segfault with PostgreSQL
    # parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Mock helper for tests
    def mock(name)
      Minitest::Mock.new(name)
    end

    # Job assertion helpers
    def assert_enqueued_with(job_class, args = nil, &block)
      if args
        assert_enqueued_jobs 1, only: job_class do
          block.call
        end
      else
        assert_enqueued_jobs 1, only: job_class do
          block.call
        end
      end
    end

    def assert_no_enqueued_jobs(job_class = nil, &block)
      if job_class
        assert_no_enqueued_jobs only: job_class do
          block.call
        end
      else
        assert_no_enqueued_jobs do
          block.call
        end
      end
    end

    # Devise Token Auth helper for API tests
    def auth_headers(user)
      # Create a token if none exists
      if user.tokens.empty?
        user.create_token
        user.save!
      end

      {
        'access-token' => user.tokens.values.first['token'],
        'client' => user.tokens.keys.first,
        'uid' => user.uid
      }
    end
  end
end
