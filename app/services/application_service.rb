# frozen_string_literal: true

# Base service class providing common functionality for all services
class ApplicationService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :errors, :result

  def initialize(attributes = {})
    super
    @errors = []
    @result = nil
  end

  def call
    raise NotImplementedError, 'Subclasses must implement #call method'
  end

  def success?
    errors.empty?
  end

  def failure?
    !success?
  end

  def add_error(message)
    errors << message
  end

  def add_errors(error_messages)
    errors.concat(Array(error_messages))
  end

  def log_info(message)
    Rails.logger.info "#{self.class.name}: #{message}"
  end

  def log_error(message)
    Rails.logger.error "#{self.class.name}: #{message}"
  end

  def log_warn(message)
    Rails.logger.warn "#{self.class.name}: #{message}"
  end

  def log_debug(message)
    Rails.logger.debug "#{self.class.name}: #{message}"
  end

  protected

  def with_error_handling
    yield
  rescue StandardError => e
    log_error("Unexpected error: #{e.message}")
    add_error(e.message)
    nil
  end

  def with_transaction(&)
    ActiveRecord::Base.transaction(&)
  end
end
