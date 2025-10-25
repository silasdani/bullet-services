# frozen_string_literal: true

namespace :webflow do
  desc "Check Webflow credentials configuration"
  task check_credentials: :environment do
    puts "Checking Webflow credentials configuration..."

    token = ENV.fetch("WEBFLOW_TOKEN")
    site_id = ENV.fetch("WEBFLOW_SITE_ID")
    collection_id = ENV.fetch("WEBFLOW_WRS_COLLECTION_ID")

    if token
      puts "✅ WEBFLOW_TOKEN is configured"
    else
      puts "❌ WEBFLOW_TOKEN is not configured"
    end

    if site_id
      puts "✅ WEBFLOW_SITE_ID is configured"
    else
      puts "❌ WEBFLOW_SITE_ID is not configured"
    end

    if collection_id
      puts "✅ WEBFLOW_WRS_COLLECTION_ID is configured"
    else
      puts "❌ WEBFLOW_WRS_COLLECTION_ID is not configured"
    end
  end

  desc "Sync Webflow WRS to Rails"
  task sync_all_wrs_to_rails: :environment do
    puts "🔄 Syncing all WRS from Webflow to Rails..."

    begin
      item_service = Webflow::ItemService.new
      offset = 0
      limit = 100

      # Get admin user once to avoid repeated queries
      admin_user = User.find_by(email: "admin@bullet.co.uk")
      if admin_user
        puts "✅ Admin user found: #{admin_user.email}"
      else
        puts "⚠️  Admin user not found - WRS will be created without user assignment"
      end

      # Initialize sync service once
      sync_service = Wrs::SyncService.new(admin_user: admin_user)

      total_items = nil
      all_items = []

      # Fetch all items first
      loop do
        puts "\n📥 Fetching WRS items (offset: #{offset}, limit: #{limit})..."
        response = item_service.list_items({ offset: offset, limit: limit })
        items = response["items"]
        break if items.nil? || items.empty?

        all_items.concat(items)

        # Check if we have more items to fetch
        total_items ||= response["pagination"]["total"]
        puts "   Retrieved #{items.size} items (Total in Webflow: #{total_items})"

        offset += limit
        break if offset >= total_items
      end

      # Process all items with the sync service
      if all_items.any?
        puts "\n" + "="*60
        puts "Processing #{all_items.size} WRS items..."
        puts "="*60

        result = sync_service.sync_batch(all_items)

        puts "\n" + "="*60
        puts "✨ Sync completed!"
        puts "   Synced: #{result[:synced]}"
        puts "   Skipped: #{result[:skipped]}"
        puts "="*60
      else
        puts "\n⚠️  No items found to sync"
      end

    rescue WebflowApiError => e
      puts "\n❌ Webflow API Error: #{e.message}"
      puts "   Status Code: #{e.status_code}"
      puts "   Response: #{e.response_body}"
    rescue => e
      puts "\n❌ Unexpected error: #{e.message}"
      puts "   #{e.backtrace.first(5).join("\n   ")}"
    end
  end
end
