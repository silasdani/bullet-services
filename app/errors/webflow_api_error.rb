# frozen_string_literal: true

# Custom error class for Webflow API errors
class WebflowApiError < ApplicationError
  attr_reader :status_code, :response_body

  def initialize(message, status_code = nil, response_body = nil)
    super(message, code: 'WEBFLOW_API_ERROR')
    @status_code = status_code
    @response_body = response_body
  end
end
