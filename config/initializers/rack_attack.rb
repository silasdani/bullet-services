# frozen_string_literal: true

# config/initializers/rack_attack.rb
class Rack::Attack
  # Allow requests from localhost
  Rack::Attack.safelist('allow-localhost') do |req|
    '127.0.0.1' == req.ip || '::1' == req.ip
  end

  # Rate limit API requests - general limit
  Rack::Attack.throttle('api/ip', limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # Stricter rate limit for write operations (POST, PUT, PATCH, DELETE)
  Rack::Attack.throttle('api/write/ip', limit: 30, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/') && %w[POST PUT PATCH DELETE].include?(req.request_method)
  end

  # Rate limit authentication requests (very strict)
  Rack::Attack.throttle('auth/ip', limit: 5, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/auth/')
  end

  # Rate limit image upload endpoints (resource intensive)
  Rack::Attack.throttle('api/images/ip', limit: 10, period: 1.minute) do |req|
    req.ip if req.path.include?('/images/upload')
  end

  # Rate limit webhook endpoints (prevent abuse)
  Rack::Attack.throttle('api/webhooks/ip', limit: 20, period: 1.minute) do |req|
    req.ip if req.path.include?('/webhooks')
  end

  # Rate limit by user token for authenticated requests
  Rack::Attack.throttle('api/user', limit: 200, period: 1.minute) do |req|
    if req.path.start_with?('/api/') && req.env['HTTP_AUTHORIZATION']
      # Extract user ID from token (simplified - you may need to adjust based on your auth setup)
      req.env['HTTP_AUTHORIZATION']
    end
  end

  # Custom response for throttled requests
  self.throttled_response = lambda do |env|
    match_data = env['rack.attack.match_data']
    now = match_data[:epoch_time]
    headers = {
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s,
      'Content-Type' => 'application/json'
    }
    [429, headers, [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]]
  end
end
