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

    # Show configuration (without secrets) for debugging
    config = Rails.application.config.freshbooks
    puts "\nConfiguration:"
    puts "  Client ID: #{config[:client_id].present? ? "#{config[:client_id][0..8]}..." : 'NOT SET'}"
    puts "  Client Secret: #{config[:client_secret].present? ? 'SET' : 'NOT SET'}"
    puts "  Redirect URI: #{config[:redirect_uri] || 'NOT SET'}"

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
      puts "\n❌ Error: #{e.message}"

      # Show detailed error response if available
      if e.respond_to?(:response_body) && e.response_body.present?
        begin
          error_data = JSON.parse(e.response_body)
          puts "\nFreshBooks Error Details:"
          puts "  Error: #{error_data['error']}" if error_data['error']
          puts "  Description: #{error_data['error_description']}" if error_data['error_description']
        rescue JSON::ParserError
          puts "\nFreshBooks Response: #{e.response_body}"
        end
      end

      puts "\nCommon issues:"
      puts '  - Authorization code expired (codes expire in ~10 minutes)'
      puts '  - Code already used (each code can only be used once)'
      puts '  - Redirect URI mismatch (must match EXACTLY, including protocol, domain, path, and trailing slashes)'
      puts '  - Invalid client credentials'
      puts '  - OAuth credentials not configured ' \
           '(FRESHBOOKS_CLIENT_ID, FRESHBOOKS_CLIENT_SECRET, FRESHBOOKS_REDIRECT_URI)'
      puts "\n💡 The redirect_uri must match exactly: #{config[:redirect_uri]}"
      puts "   Verify it's registered in FreshBooks app settings: https://my.freshbooks.com/#/developer"
      exit 1
    rescue StandardError => e
      puts "❌ Unexpected error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  desc 'Show OAuth authorization URL with exact redirect_uri'
  task show_auth_url: :environment do
    config = Rails.application.config.freshbooks

    if config[:client_id].blank? || config[:redirect_uri].blank?
      puts '❌ Error: FRESHBOOKS_CLIENT_ID and FRESHBOOKS_REDIRECT_URI must be set'
      exit 1
    end

    auth_url = "https://auth.freshbooks.com/oauth/authorize?client_id=#{config[:client_id]}&response_type=code&redirect_uri=#{CGI.escape(config[:redirect_uri])}"

    puts 'OAuth Authorization URL:'
    puts auth_url
    puts "\n⚠️  Before visiting:"
    puts "   Ensure this redirect_uri is registered in FreshBooks: #{config[:redirect_uri]}"
    puts '   Register at: https://my.freshbooks.com/#/developer'
    puts "\n   After authorization, copy the 'code' parameter and run:"
    puts '   rails freshbooks:exchange_code[CODE]'
  end

  desc 'Verify OAuth configuration'
  task verify_config: :environment do
    config = Rails.application.config.freshbooks

    puts 'Checking FreshBooks OAuth configuration...'
    puts

    issues = []

    if config[:client_id].blank?
      issues << 'FRESHBOOKS_CLIENT_ID is not set'
    else
      puts "✅ Client ID: #{config[:client_id][0..8]}..."
    end

    if config[:client_secret].blank?
      issues << 'FRESHBOOKS_CLIENT_SECRET is not set'
    else
      puts '✅ Client Secret: SET'
    end

    if config[:redirect_uri].blank?
      issues << 'FRESHBOOKS_REDIRECT_URI is not set'
    else
      puts "✅ Redirect URI: #{config[:redirect_uri]}"
    end

    if issues.any?
      puts "\n❌ Configuration issues found:"
      issues.each { |issue| puts "  - #{issue}" }
      puts "\nPlease set these environment variables before attempting OAuth exchange."
      exit 1
    else
      puts "\n✅ All OAuth credentials are configured!"
      puts "\nTo get an authorization code, visit:"
      puts "https://auth.freshbooks.com/oauth/authorize?client_id=#{config[:client_id]}&response_type=code&redirect_uri=#{CGI.escape(config[:redirect_uri])}"

      # Test if callback endpoint is accessible
      if config[:redirect_uri].present?
        puts "\nTesting callback endpoint accessibility..."
        begin
          response = HTTParty.get(config[:redirect_uri], timeout: 5)
          if [400, 405].include?(response.code)
            # 400/405 is expected for GET without code param, means endpoint exists
            puts "✅ Callback endpoint is accessible (returned #{response.code}, which is expected)"
          elsif response.success?
            puts '✅ Callback endpoint is accessible'
          else
            puts "⚠️  Callback endpoint returned: #{response.code}"
          end
        rescue Net::OpenTimeout, Errno::ECONNREFUSED, SocketError => e
          puts "❌ Cannot reach callback endpoint: #{e.message}"
          puts '   Make sure your ngrok tunnel is running and pointing to your Rails server'
        rescue StandardError => e
          puts "⚠️  Could not test callback endpoint: #{e.message}"
        end
      end
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
    config = Rails.application.config.freshbooks
    refresh_token = ENV.fetch('FRESHBOOKS_REFRESH_TOKEN', nil) || FreshbooksToken.current&.refresh_token
    client_id = config[:client_id]
    client_secret = config[:client_secret]
    redirect_uri = config[:redirect_uri]

    if refresh_token.blank? || client_id.blank? || client_secret.blank?
      puts 'Error: FRESHBOOKS_REFRESH_TOKEN, FRESHBOOKS_CLIENT_ID, and FRESHBOOKS_CLIENT_SECRET must be set'
      exit 1
    end

    if redirect_uri.blank?
      puts 'Error: FRESHBOOKS_REDIRECT_URI must be set (required by FreshBooks for token refresh)'
      exit 1
    end

    puts 'Refreshing access token...'

    token_url = "#{config[:api_base_url]}/auth/oauth/token"
    response = HTTParty.post(
      token_url,
      body: {
        grant_type: 'refresh_token',
        refresh_token: refresh_token,
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    if response.success?
      data = response.parsed_response
      access_token = data['access_token']
      new_refresh_token = data['refresh_token'] || refresh_token
      expires_in = data['expires_in']

      # Update database if we have a token record
      token = FreshbooksToken.current
      if token
        token.update!(
          access_token: access_token,
          refresh_token: new_refresh_token,
          token_expires_at: Time.current + expires_in.seconds
        )
        puts "\n✅ Token refreshed and saved to database!\n\n"
      else
        puts "\n✅ Token refreshed!\n\n"
        puts "Update your .env file:\n\n"
        puts "FRESHBOOKS_ACCESS_TOKEN=#{access_token}"
        puts "FRESHBOOKS_REFRESH_TOKEN=#{new_refresh_token}" if new_refresh_token != refresh_token
      end
      puts "Token expires in: #{expires_in} seconds (#{(expires_in / 3600.0).round(2)} hours)"
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

  namespace :invoices do
    desc 'Verify all FreshBooks invoices are in sync'
    task verify_sync: :environment do
      puts 'Verifying FreshBooks invoice sync...'
      puts '=' * 80

      stats = {
        total: 0,
        synced: 0,
        out_of_sync: 0,
        errors: []
      }

      FreshbooksInvoice.find_each do |fb_invoice|
        stats[:total] += 1
        print "Invoice #{fb_invoice.freshbooks_id}... "

        result = fb_invoice.verify_sync

        if result[:synced]
          stats[:synced] += 1
          puts '✅ Synced'
        else
          stats[:out_of_sync] += 1
          puts "❌ Out of sync: #{result[:errors].join(', ')}"
          stats[:errors] << { id: fb_invoice.freshbooks_id, errors: result[:errors] }
        end
      end

      puts "\n#{'=' * 80}"
      puts 'Summary:'
      puts "  Total invoices: #{stats[:total]}"
      puts "  ✅ Synced: #{stats[:synced]}"
      puts "  ❌ Out of sync: #{stats[:out_of_sync]}"
      puts '=' * 80

      if stats[:out_of_sync].positive?
        puts "\n⚠️  Found #{stats[:out_of_sync]} invoice(s) out of sync."
        puts "Run 'rake freshbooks:invoices:reconcile_all' to fix them."
      end
    end

    desc 'Reconcile all FreshBooks invoices (sync from API and reconcile payments)'
    task reconcile_all: :environment do
      puts 'Reconciling all FreshBooks invoices...'
      puts '=' * 80

      stats = {
        total: 0,
        synced: 0,
        reconciled: 0,
        failed: 0,
        errors: []
      }

      FreshbooksInvoice.find_each do |fb_invoice|
        stats[:total] += 1
        print "Invoice #{fb_invoice.freshbooks_id}... "

        begin
          lifecycle_service = Freshbooks::InvoiceLifecycleService.new(fb_invoice)
          lifecycle_service.sync_from_freshbooks
          lifecycle_service.reconcile_payments

          if lifecycle_service.success?
            stats[:synced] += 1
            stats[:reconciled] += 1
            puts '✅ Synced & Reconciled'
          else
            stats[:failed] += 1
            error_msg = lifecycle_service.errors.join(', ')
            puts "❌ Failed: #{error_msg}"
            stats[:errors] << { id: fb_invoice.freshbooks_id, errors: lifecycle_service.errors }
          end
        rescue StandardError => e
          stats[:failed] += 1
          error_msg = e.message
          puts "❌ Error: #{error_msg}"
          stats[:errors] << { id: fb_invoice.freshbooks_id, errors: [error_msg] }
        end
      end

      puts "\n#{'=' * 80}"
      puts 'Summary:'
      puts "  Total invoices: #{stats[:total]}"
      puts "  ✅ Synced & Reconciled: #{stats[:synced]}"
      puts "  ❌ Failed: #{stats[:failed]}"
      puts '=' * 80

      if stats[:errors].any?
        puts "\nErrors encountered:"
        stats[:errors].first(10).each do |error|
          puts "  Invoice #{error[:id]}: #{error[:errors].join(', ')}"
        end
        puts "  ... and #{stats[:errors].length - 10} more" if stats[:errors].length > 10
      end
    end

    desc 'Reconcile a specific invoice by FreshBooks ID'
    task :reconcile, [:freshbooks_id] => :environment do |_t, args|
      freshbooks_id = args[:freshbooks_id]

      if freshbooks_id.blank?
        puts 'Error: FreshBooks invoice ID is required'
        puts 'Usage: rails freshbooks:invoices:reconcile[FRESHBOOKS_ID]'
        exit 1
      end

      fb_invoice = FreshbooksInvoice.find_by(freshbooks_id: freshbooks_id)

      unless fb_invoice
        puts "❌ Invoice not found: #{freshbooks_id}"
        exit 1
      end

      puts "Reconciling invoice #{freshbooks_id}..."
      puts '=' * 80

      lifecycle_service = Freshbooks::InvoiceLifecycleService.new(fb_invoice)
      lifecycle_service.sync_from_freshbooks
      lifecycle_service.reconcile_payments

      if lifecycle_service.success?
        puts '✅ Invoice synced and reconciled successfully!'
        puts "\nCurrent status:"
        puts "  Status: #{fb_invoice.reload.status}"
        puts "  Amount: #{fb_invoice.amount}"
        puts "  Outstanding: #{fb_invoice.amount_outstanding}"
        puts "  Payments: #{fb_invoice.freshbooks_payments.count}"
      else
        puts "❌ Failed: #{lifecycle_service.errors.join(', ')}"
        exit 1
      end
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
