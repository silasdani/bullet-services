# frozen_string_literal: true

namespace :webflow do
  desc 'Test Webflow API connection'
  task test_connection: :environment do
    puts "Testing Webflow API connection..."

    begin
      webflow = WebflowService.new
      sites = webflow.list_sites

      puts "✅ Connection successful!"
      puts "Found #{sites['sites']&.length || 0} sites"

      if sites['sites']&.any?
        puts "\nSites:"
        sites['sites'].each do |site|
          puts "  - #{site['name']} (ID: #{site['_id']})"
        end
      end

    rescue WebflowApiError => e
      puts "❌ Webflow API Error: #{e.message}"
      puts "Status Code: #{e.status_code}"
      puts "Response: #{e.response_body}"
    rescue => e
      puts "❌ Unexpected error: #{e.message}"
    end
  end

  desc 'List collections for a site'
  task :list_collections, [:site_id] => :environment do |task, args|
    site_id = args[:site_id]

    unless site_id
      puts "Please provide a site ID: rake webflow:list_collections[site_id]"
      exit 1
    end

    puts "Fetching collections for site #{site_id}..."

    begin
      webflow = WebflowService.new
      collections = webflow.list_collections(site_id)

      if collections['collections']&.any?
        puts "\nCollections:"
        collections['collections'].each do |collection|
          puts "  - #{collection['displayName']} (ID: #{collection['id']})"
          puts "    Slug: #{collection['slug']}"
          puts "    Last Updated: #{collection['lastUpdated'] || 'Never'}"
          puts ""
        end
      else
        puts "No collections found for this site."
      end

    rescue WebflowApiError => e
      puts "❌ Error: #{e.message}"
    end
  end

  desc 'List items in a collection'
  task :list_items, [:site_id, :collection_id] => :environment do |task, args|
    site_id = args[:site_id]
    collection_id = args[:collection_id]

    unless site_id && collection_id
      puts "Please provide site ID and collection ID: rake webflow:list_items[site_id,collection_id]"
      exit 1
    end

    puts "Fetching items from collection #{collection_id} in site #{site_id}..."

    begin
      webflow = WebflowService.new
      items = webflow.list_items(site_id, collection_id)

      if items['items']&.any?
        puts "\nItems:"

        items['items'].last(10).each do |item|
          puts "  - ID: #{item['id']}"
          puts "    Created On: #{item['createdOn']}"
          puts "    Last Updated: #{item['lastUpdated'] || 'Never'}"
          puts "    Last Published: #{item['lastPublished'] || 'Never'}"
          puts "    Is Archived: #{item['isArchived']}"
          puts "    Is Draft: #{item['isDraft']}"
          puts "    Field Data:"

          item['fieldData'].each do |field, value|
            puts "      - #{field}: #{value.inspect}"
          end
          puts ""
        end
      else
        puts "No items found in this collection."
      end

    rescue WebflowApiError => e
      puts "❌ Error: #{e.message}"
    end
  end

  desc 'Send a test window schedule repair to Webflow'
  task :send_test_window_schedule_repair, [:window_schedule_repair_id] => :environment do |task, args|
    window_schedule_repair_id = args[:window_schedule_repair_id]

    unless window_schedule_repair_id
      puts "Please provide a window schedule repair ID: rake webflow:send_test_window_schedule_repair[window_schedule_repair_id]"
      exit 1
    end

    begin
      window_schedule_repair = WindowScheduleRepair.find(window_schedule_repair_id)
      puts "Sending window schedule repair #{window_schedule_repair.id} to Webflow..."

      webflow = WebflowService.new
      result = webflow.send_window_schedule_repair(window_schedule_repair)

      puts "✅ Window schedule repair sent successfully!"
      puts "Item ID: #{result['_id']}"
      puts "Created: #{result['createdOn']}"

    rescue ActiveRecord::RecordNotFound
      puts "❌ Window schedule repair with ID #{window_schedule_repair_id} not found."
    rescue WebflowApiError => e
      puts "❌ Webflow API Error: #{e.message}"
      puts "Status Code: #{e.status_code}"
    rescue => e
      puts "❌ Unexpected error: #{e.message}"
    end
  end

  desc 'Check Webflow credentials configuration'
  task check_credentials: :environment do
    puts "Checking Webflow credentials configuration..."

    credentials = Rails.application.credentials

    if credentials.webflow_token
      puts "✅ WEBFLOW_TOKEN is configured"
    else
      puts "❌ WEBFLOW_TOKEN is not configured"
    end

    if credentials.webflow_site_id
      puts "✅ WEBFLOW_SITE_ID is configured"
    else
      puts "❌ WEBFLOW_SITE_ID is not configured"
    end

    if credentials.webflow_collection_id
      puts "✅ WEBFLOW_COLLECTION_ID is configured"
    else
      puts "❌ WEBFLOW_COLLECTION_ID is not configured"
    end

    puts "\nTo configure credentials, run:"
    puts "rails credentials:edit"
    puts "\nAdd the following:"
    puts "webflow_token: 'your_webflow_api_token'"
    puts "webflow_site_id: 'your_site_id'"
    puts "webflow_collection_id: 'your_collection_id'"
  end
end
