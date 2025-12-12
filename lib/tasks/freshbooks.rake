# frozen_string_literal: true

namespace :freshbooks do
  desc 'Get FreshBooks OAuth tokens (run this after completing OAuth flow)'
  task :setup_tokens, [:code] => :environment do |_t, args|
    code = args[:code]

    if code.blank?
      puts <<~INSTRUCTIONS
        To get your FreshBooks tokens, follow these steps:

        1. Visit this URL in your browser (replace YOUR_CLIENT_ID):
           https://auth.freshbooks.com/oauth/authorize?client_id=#{ENV.fetch('FRESHBOOKS_CLIENT_ID', nil)}&response_type=code&redirect_uri=#{CGI.escape(ENV['FRESHBOOKS_REDIRECT_URI'] || '')}

        2. Authorize the application

        3. You'll be redirected to your redirect_uri with a 'code' parameter

        4. Run this command with the code:
           rails freshbooks:exchange_code[YOUR_CODE_HERE]

        Or manually exchange the code using:
        rails freshbooks:exchange_code[YOUR_CODE_HERE]
      INSTRUCTIONS
      exit
    end

    Rake::Task['freshbooks:exchange_code'].invoke(code)
  end

  desc 'Exchange authorization code for tokens'
  task :exchange_code, [:code] => :environment do |_t, args|
    code = args[:code]

    if code.blank?
      puts 'Error: Authorization code is required'
      puts 'Usage: rails freshbooks:exchange_code[YOUR_CODE]'
      exit 1
    end

    puts 'Exchanging authorization code for tokens...'
    puts "  Code length: #{code.length}"

    begin
      result = Freshbooks::OauthService.exchange_code(code)
      token = result[:token]
      expires_in = result[:expires_in]
      expires_hours = (expires_in / 3600.0).round(2)

      puts "\n✅ Success! Tokens have been saved to the database.\n\n"
      puts "Business ID: #{result[:business_id]}"
      puts "Token expires in: #{expires_in} seconds (#{expires_hours} hours)"
      puts "\nOptional: Add these to your .env file if you prefer environment variables:\n\n"
      puts "FRESHBOOKS_ACCESS_TOKEN=#{token.access_token}"
      puts "FRESHBOOKS_REFRESH_TOKEN=#{token.refresh_token}"
      puts "FRESHBOOKS_BUSINESS_ID=#{token.business_id}"
      puts "\n"
    rescue FreshbooksError => e
      puts "❌ Error: #{e.message}"
      puts "\nCommon issues:"
      puts '  - Authorization code expired (codes expire in ~10 minutes)'
      puts '  - Code already used'
      puts '  - Redirect URI mismatch (must match exactly)'
      puts '  - Invalid client credentials'
      puts '  - OAuth credentials not configured (FRESHBOOKS_CLIENT_ID, FRESHBOOKS_CLIENT_SECRET, FRESHBOOKS_REDIRECT_URI)'
      exit 1
    rescue StandardError => e
      puts "❌ Unexpected error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  desc 'Get business ID from existing access token'
  task get_business_id: :environment do
    access_token = ENV['FRESHBOOKS_ACCESS_TOKEN'] || FreshbooksToken.current&.access_token

    if access_token.blank?
      puts 'Error: FRESHBOOKS_ACCESS_TOKEN must be set or token must exist in database'
      exit 1
    end

    puts 'Fetching business ID...'
    business_info = fetch_business_info(access_token)
    business_id = business_info['business_id']

    if business_id.present?
      puts "\n✅ Business ID found: #{business_id}"
      puts "\nAdd to your .env file:"
      puts "FRESHBOOKS_BUSINESS_ID=#{business_id}"

      # Update database if token exists
      token = FreshbooksToken.current
      if token && token.business_id.blank?
        token.update!(business_id: business_id)
        puts "\n✅ Updated database record"
      end
    else
      puts "\n❌ Could not fetch business ID"
      puts 'Make sure your access token is valid'
    end
  end

  desc 'Refresh access token using refresh token'
  task refresh_token: :environment do
    refresh_token = ENV.fetch('FRESHBOOKS_REFRESH_TOKEN', nil)
    client_id = ENV.fetch('FRESHBOOKS_CLIENT_ID', nil)
    client_secret = ENV.fetch('FRESHBOOKS_CLIENT_SECRET', nil)

    if refresh_token.blank? || client_id.blank? || client_secret.blank?
      puts 'Error: FRESHBOOKS_REFRESH_TOKEN, FRESHBOOKS_CLIENT_ID, and FRESHBOOKS_CLIENT_SECRET must be set'
      exit 1
    end

    puts 'Refreshing access token...'

    response = HTTParty.post(
      'https://auth.freshbooks.com/oauth/token',
      body: {
        grant_type: 'refresh_token',
        refresh_token: refresh_token,
        client_id: client_id,
        client_secret: client_secret
      },
      headers: { 'Content-Type' => 'application/json' }
    )

    if response.success?
      data = response.parsed_response
      access_token = data['access_token']
      new_refresh_token = data['refresh_token'] || refresh_token
      expires_in = data['expires_in']

      puts "\n✅ Token refreshed!\n\n"
      puts "Update your .env file:\n\n"
      puts "FRESHBOOKS_ACCESS_TOKEN=#{access_token}"
      puts "FRESHBOOKS_REFRESH_TOKEN=#{new_refresh_token}" if new_refresh_token != refresh_token
      puts "\nToken expires in: #{expires_in} seconds (#{(expires_in / 3600.0).round(2)} hours)"
    else
      puts "❌ Error: #{response.code}"
      puts response.body
      exit 1
    end
  end

  desc 'Test FreshBooks connection'
  task test: :environment do
    puts 'Testing FreshBooks connection...'
    puts "Business ID: #{ENV['FRESHBOOKS_BUSINESS_ID'] || FreshbooksToken.current&.business_id}"

    begin
      # Try a simpler endpoint first - get account info
      access_token = ENV['FRESHBOOKS_ACCESS_TOKEN'] || FreshbooksToken.current&.access_token
      business_id = ENV['FRESHBOOKS_BUSINESS_ID'] || FreshbooksToken.current&.business_id

      puts "\nTesting API endpoint..."
      response = HTTParty.get(
        "https://api.freshbooks.com/accounting/account/#{business_id}/users/clients",
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Api-Version' => 'alpha',
          'Content-Type' => 'application/json'
        },
        query: { page: 1, per_page: 1 }
      )

      puts "Response code: #{response.code}"

      if response.success?
        result = response.parsed_response
        total = result.dig('response', 'result', 'total') || 0
        puts '✅ Connection successful!'
        puts "Found #{total} clients"
      else
        puts "❌ API Error: #{response.code}"
        puts "Response: #{response.body}"
        puts "\nTrying alternative endpoint..."

        # Try the accounting API v2
        response2 = HTTParty.get(
          "https://api.freshbooks.com/accounting/account/#{business_id}/users/clients",
          headers: {
            'Authorization' => "Bearer #{access_token}",
            'Api-Version' => '2023-02-20',
            'Content-Type' => 'application/json'
          },
          query: { page: 1, per_page: 1 }
        )

        if response2.success?
          puts '✅ Connection successful with API version 2023-02-20!'
        else
          puts "❌ Also failed: #{response2.code}"
          puts "Response: #{response2.body}"
        end
      end
    rescue FreshbooksError => e
      puts "❌ Connection failed: #{e.message}"
      puts "Status: #{e.status_code}" if e.respond_to?(:status_code)
      exit 1
    rescue StandardError => e
      puts "❌ Error: #{e.message}"
      puts e.backtrace.first(3).join("\n")
      exit 1
    end
  end

  private

  def fetch_business_info(access_token)
    response = HTTParty.get(
      'https://api.freshbooks.com/auth/api/v1/users/me',
      headers: {
        'Authorization' => "Bearer #{access_token}",
        'Api-Version' => 'alpha'
      }
    )

    if response.success?
      data = response.parsed_response
      business_data = data.dig('response', 'business') || data.dig('response', 'business_memberships', 0, 'business')

      business_id = business_data&.dig('business_id') ||
                    business_data&.dig('account_id') ||
                    business_data&.dig('id') ||
                    data.dig('response', 'account_id')

      user_id = business_data&.dig('account_id') ||
                data.dig('response', 'account_id') ||
                data.dig('response', 'id')

      {
        'business_id' => business_id,
        'user_id' => user_id
      }
    else
      puts "\n⚠️  Warning: Could not fetch business info (status: #{response.code})"
      puts "Response: #{response.body}"
      { 'business_id' => nil, 'user_id' => nil }
    end
  end
end
