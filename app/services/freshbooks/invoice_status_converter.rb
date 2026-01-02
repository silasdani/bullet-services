# frozen_string_literal: true

module Freshbooks
  # Handles conversion between FreshBooks API numeric status codes and human-readable strings
  #
  # FreshBooks API uses numeric status codes:
  #   1 = draft
  #   2 = sent
  #   3 = viewed
  #   4 = paid
  #   5 = void
  #
  # IMPORTANT: The FreshBooks API update endpoint does NOT allow setting status to 'void' (5).
  # When updating an invoice, status can only be set to: 'draft', 'sent', 'viewed', or 'disputed'.
  # Void status is read-only and cannot be set via the update API endpoint.
  #
  # This module provides bidirectional conversion and validation
  module InvoiceStatusConverter
    # Numeric status codes used by FreshBooks API
    DRAFT = 1
    SENT = 2
    VIEWED = 3
    PAID = 4
    VOID = 5

    # String status values used in the application
    STATUS_DRAFT = 'draft'
    STATUS_SENT = 'sent'
    STATUS_VIEWED = 'viewed'
    STATUS_PAID = 'paid'
    STATUS_VOID = 'void'
    STATUS_VOIDED = 'voided' # Alternative form

    # Mapping from numeric codes to string values
    NUMERIC_TO_STRING = {
      DRAFT => STATUS_DRAFT,
      SENT => STATUS_SENT,
      VIEWED => STATUS_VIEWED,
      PAID => STATUS_PAID,
      VOID => STATUS_VOID
    }.freeze

    # Mapping from string values to numeric codes (handles variations)
    STRING_TO_NUMERIC = {
      STATUS_DRAFT => DRAFT,
      STATUS_SENT => SENT,
      STATUS_VIEWED => VIEWED,
      STATUS_PAID => PAID,
      STATUS_VOID => VOID,
      STATUS_VOIDED => VOID # Both 'void' and 'voided' map to 5
    }.freeze

    # Valid numeric status codes
    VALID_NUMERIC_STATUSES = NUMERIC_TO_STRING.keys.freeze

    # Valid string status values
    VALID_STRING_STATUSES = STRING_TO_NUMERIC.keys.freeze

    class << self
      # Converts a status value to FreshBooks API numeric format
      #
      # @param status [Integer, String, Symbol] The status to convert
      # @return [Integer] The numeric status code
      # @raise [ArgumentError] if status is invalid
      def to_numeric(status)
        return status if status.is_a?(Integer) && valid_numeric?(status)
        return status.to_i if status.is_a?(String) && status.match?(/\A\d+\z/)

        normalized = normalize_string(status)
        STRING_TO_NUMERIC.fetch(normalized) do
          raise ArgumentError, "Invalid FreshBooks invoice status: #{status.inspect}"
        end
      end

      # Converts a numeric status code to a human-readable string
      #
      # @param status [Integer, String] The numeric status code
      # @return [String] The string status value
      # @raise [ArgumentError] if status is invalid
      def to_string(status)
        numeric = status.is_a?(Integer) ? status : status.to_i
        NUMERIC_TO_STRING.fetch(numeric) do
          raise ArgumentError, "Invalid FreshBooks invoice status code: #{numeric.inspect}"
        end
      end

      # Normalizes a string status value (handles case and variations)
      #
      # @param status [String, Symbol] The status to normalize
      # @return [String] The normalized status string
      def normalize_string(status)
        status.to_s.downcase.strip
      end

      # Checks if a numeric status code is valid
      #
      # @param status [Integer] The status code to validate
      # @return [Boolean]
      def valid_numeric?(status)
        VALID_NUMERIC_STATUSES.include?(status)
      end

      # Checks if a string status value is valid
      #
      # @param status [String, Symbol] The status to validate
      # @return [Boolean]
      def valid_string?(status)
        normalized = normalize_string(status)
        VALID_STRING_STATUSES.include?(normalized) || normalized == STATUS_VOIDED
      end

      # Safely converts status to numeric, returning nil for invalid values
      #
      # @param status [Integer, String, Symbol, nil] The status to convert
      # @return [Integer, nil] The numeric status code or nil if invalid
      def to_numeric_safe(status)
        to_numeric(status)
      rescue ArgumentError
        nil
      end

      # Safely converts status to string, returning nil for invalid values
      #
      # @param status [Integer, String, nil] The status to convert
      # @return [String, nil] The string status value or nil if invalid
      def to_string_safe(status)
        to_string(status)
      rescue ArgumentError
        nil
      end
    end
  end
end
