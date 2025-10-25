# frozen_string_literal: true

# app/errors/application_error.rb
class ApplicationError < StandardError
  attr_reader :code, :details

  def initialize(message, code: nil, details: nil)
    super(message)
    @code = code
    @details = details
  end
end
