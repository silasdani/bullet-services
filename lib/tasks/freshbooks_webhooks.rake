# frozen_string_literal: true

namespace :freshbooks do
  namespace :webhooks do
    desc 'List all registered webhooks'
    task list: :environment do
      webhooks = Freshbooks::Webhooks.new
      events = webhooks.list

      if events.empty?
        puts 'No webhooks registered.'
      else
        puts "\nRegistered Webhooks:\n\n"
        events.each do |event|
          puts "  ID: #{event['id']}"
          puts "  Event: #{event['event']}"
          puts "  URL: #{event['uri']}"
          puts "  Status: #{event['verified'] ? 'Verified' : 'Pending Verification'}"
          puts '  ---'
        end
      end
    rescue FreshbooksError => e
      puts "❌ Error: #{e.message}"
      exit 1
    end

    desc 'Register a webhook for payment events'
    task register_payment: :environment do
      callback_url = ENV['WEBHOOK_URL'] || ask_for_webhook_url

      puts "\nRegistering webhook for payment events..."
      puts "  URL: #{callback_url}"
      puts "\nNote: Verifier will be sent by FreshBooks during verification"

      begin
        webhooks = Freshbooks::Webhooks.new
        result = webhooks.create(
          event: 'payment.create',
          callback_url: callback_url
        )

        puts "\n✅ Webhook registered successfully!"
        puts "\nCallback ID: #{result['id'] || result['callbackid']}"
        puts "Event: #{result['event']}"
        puts "Status: #{result['verified'] ? 'Verified' : 'Pending Verification'}"

        unless result['verified']
          puts "\n⚠️  Webhook needs verification!"
          puts 'FreshBooks will send a verification request to your webhook URL.'
          puts 'The verification code will be sent in the request parameters.'
          puts 'Your webhook controller will automatically handle the verification.'
          puts "\nTo manually verify, run:"
          puts "  rails freshbooks:webhooks:verify[#{result['id'] || result['callbackid']},VERIFICATION_CODE]"
        end
      rescue FreshbooksError => e
        puts "❌ Error: #{e.message}"
        puts "Response: #{e.response_body}" if e.respond_to?(:response_body)
        exit 1
      end
    end

    desc 'Register webhooks for invoice and payment events'
    task register_all: :environment do
      callback_url = ENV['WEBHOOK_URL'] || ask_for_webhook_url

      events = ['payment.create', 'payment.updated', 'invoice.create', 'invoice.updated']

      puts "\nRegistering webhooks..."
      puts "  Base URL: #{callback_url}\n"

      webhooks = Freshbooks::Webhooks.new
      registered = []

      events.each do |event|
        puts "\nRegistering #{event}..."
        begin
          result = webhooks.create(
            event: event,
            callback_url: callback_url
          )
          registered << { event: event, id: result['id'] || result['callbackid'], verified: result['verified'] }
          puts "  ✅ Registered (ID: #{result['id'] || result['callbackid']})"
        rescue FreshbooksError => e
          puts "  ❌ Failed: #{e.message}"
        end
      end

      puts "\n\nSummary:"
      puts "  Registered: #{registered.length}/#{events.length}"
      registered.each do |r|
        status = r[:verified] ? 'Verified' : 'Pending'
        puts "    - #{r[:event]}: #{status} (ID: #{r[:id]})"
      end
    end

    desc 'Verify a webhook with verification code'
    task :verify, [:callback_id, :verification_code] => :environment do |_t, args|
      callback_id = args[:callback_id]
      verification_code = args[:verification_code]

      if callback_id.blank? || verification_code.blank?
        puts 'Error: Callback ID and verification code are required'
        puts 'Usage: rails freshbooks:webhooks:verify[CALLBACK_ID,VERIFICATION_CODE]'
        exit 1
      end

      begin
        webhooks = Freshbooks::Webhooks.new
        result = webhooks.verify(callback_id, verification_code)

        if result['verified']
          puts "✅ Webhook verified successfully!"
        else
          puts "⚠️  Webhook verification returned, but status is still unverified"
        end
      rescue FreshbooksError => e
        puts "❌ Error: #{e.message}"
        exit 1
      end
    end

    desc 'Resend verification code for a webhook'
    task :resend_verification, [:callback_id] => :environment do |_t, args|
      callback_id = args[:callback_id]

      if callback_id.blank?
        puts 'Error: Callback ID is required'
        puts 'Usage: rails freshbooks:webhooks:resend_verification[CALLBACK_ID]'
        exit 1
      end

      begin
        webhooks = Freshbooks::Webhooks.new
        result = webhooks.resend_verification(callback_id)
        puts "✅ Verification code resent!"
        puts "FreshBooks will send a new verification request to your webhook URL."
      rescue FreshbooksError => e
        puts "❌ Error: #{e.message}"
        exit 1
      end
    end

    desc 'Delete a webhook by ID'
    task :delete, [:webhook_id] => :environment do |_t, args|
      webhook_id = args[:webhook_id]

      if webhook_id.blank?
        puts 'Error: Webhook ID is required'
        puts 'Usage: rails freshbooks:webhooks:delete[WEBHOOK_ID]'
        exit 1
      end

      begin
        webhooks = Freshbooks::Webhooks.new
        webhooks.delete(webhook_id)
        puts "✅ Webhook #{webhook_id} deleted successfully"
      rescue FreshbooksError => e
        puts "❌ Error: #{e.message}"
        exit 1
      end
    end

    private

    def ask_for_webhook_url
      print 'Enter your webhook URL (e.g., https://yourdomain.com/api/v1/webhooks/freshbooks): '
      $stdin.gets.chomp
    end

  end
end
