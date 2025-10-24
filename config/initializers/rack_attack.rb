# frozen_string_literal: true

# config/initializers/rack_attack.rb
class Rack::Attack
  # Allow requests from localhost
  Rack::Attack.safelist('allow-localhost') do |req|
    '127.0.0.1' == req.ip || '::1' == req.ip
  end

  # Rate limit API requests
  Rack::Attack.throttle('api/ip', limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # Rate limit authentication requests
  Rack::Attack.throttle('auth/ip', limit: 5, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/auth/')
  end

  # Rate limit by user token for authenticated requests
  Rack::Attack.throttle('api/user', limit: 200, period: 1.minute) do |req|
    if req.path.start_with?('/api/') && req.env['HTTP_AUTHORIZATION']
      # Extract user ID from token (simplified - you may need to adjust based on your auth setup)
      req.env['HTTP_AUTHORIZATION']
    end
  end
end
