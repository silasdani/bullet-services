# frozen_string_literal: true

# VAT Rate Configuration
# Set via environment variable VAT_RATE (default: 0.20 = 20%)
# Example: VAT_RATE=0.20 in .env or environment variables
VAT_RATE = ENV.fetch('VAT_RATE', '0.20').to_f

# Validate VAT rate is reasonable
if VAT_RATE < 0 || VAT_RATE > 1
  raise "Invalid VAT_RATE: #{VAT_RATE}. Must be between 0 and 1 (e.g., 0.20 for 20%)"
end

Rails.logger.info "VAT Rate configured: #{(VAT_RATE * 100).round(2)}%"
