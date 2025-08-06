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

  desc 'List all sites'
  task list_sites: :environment do
    puts "Fetching Webflow sites..."

    begin
      webflow = WebflowService.new
      sites = webflow.list_sites

      if sites['sites']&.any?
        puts "\nSites:"

        sites['sites'].each do |site|
          puts "  - #{site['displayName']} (ID: #{site['id']})"
          puts "    Short Name: #{site['shortName']}"
          puts "    Preview URL: #{site['previewUrl']}"
          puts "    Created On: #{site['createdOn']}"
          puts "    Last Updated: #{site['lastUpdated'] || 'Never'}"
          puts "    Custom Domains: #{site['customDomains']&.map { |d| d['url'] }.join(', ') || 'None'}"
          puts "    Data Collection Enabled: #{site['dataCollectionEnabled']}"
          puts "    Data Collection Type: #{site['dataCollectionType']}"
          puts ""
        end
      else
        puts "No sites found."
      end

    rescue WebflowApiError => e
      puts "❌ Error: #{e.message}"
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

  desc 'Send a test quotation to Webflow'
  task :send_test_quotation, [:quotation_id] => :environment do |task, args|
    quotation_id = args[:quotation_id]

    unless quotation_id
      puts "Please provide a quotation ID: rake webflow:send_test_quotation[quotation_id]"
      exit 1
    end

    begin
      quotation = Quotation.find(quotation_id)
      puts "Sending quotation #{quotation.id} to Webflow..."

      webflow = WebflowService.new
      result = webflow.send_quotation(quotation)

      puts "✅ Quotation sent successfully!"
      puts "Item ID: #{result['_id']}"
      puts "Created: #{result['createdOn']}"

    rescue ActiveRecord::RecordNotFound
      puts "❌ Quotation with ID #{quotation_id} not found."
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

  desc 'Show Webflow API endpoints'
  task endpoints: :environment do
    puts "Webflow API Endpoints:"
    puts "\nSites:"
    puts "  GET  /api/v1/webflow/sites"
    puts "  GET  /api/v1/webflow/sites/:site_id"

    puts "\nCollections:"
    puts "  GET    /api/v1/webflow/sites/:site_id/collections"
    puts "  GET    /api/v1/webflow/sites/:site_id/collections/:collection_id"
    puts "  POST   /api/v1/webflow/sites/:site_id/collections"
    puts "  PATCH  /api/v1/webflow/sites/:site_id/collections/:collection_id"
    puts "  DELETE /api/v1/webflow/sites/:site_id/collections/:collection_id"

    puts "\nCollection Items:"
    puts "  GET    /api/v1/webflow/sites/:site_id/collections/:collection_id/items"
    puts "  GET    /api/v1/webflow/sites/:site_id/collections/:collection_id/items/:item_id"
    puts "  POST   /api/v1/webflow/sites/:site_id/collections/:collection_id/items"
    puts "  PATCH  /api/v1/webflow/sites/:site_id/collections/:collection_id/items/:item_id"
    puts "  DELETE /api/v1/webflow/sites/:site_id/collections/:collection_id/items/:item_id"
    puts "  POST   /api/v1/webflow/sites/:site_id/collections/:collection_id/items/publish"
    puts "  POST   /api/v1/webflow/sites/:site_id/collections/:collection_id/items/unpublish"

    puts "\nForms:"
    puts "  GET  /api/v1/webflow/sites/:site_id/forms"
    puts "  GET  /api/v1/webflow/sites/:site_id/forms/:form_id"
    puts "  POST /api/v1/webflow/sites/:site_id/forms/:form_id/submissions"

    puts "\nAssets:"
    puts "  GET    /api/v1/webflow/sites/:site_id/assets"
    puts "  GET    /api/v1/webflow/sites/:site_id/assets/:asset_id"
    puts "  POST   /api/v1/webflow/sites/:site_id/assets"
    puts "  PATCH  /api/v1/webflow/sites/:site_id/assets/:asset_id"
    puts "  DELETE /api/v1/webflow/sites/:site_id/assets/:asset_id"

    puts "\nUsers:"
    puts "  GET    /api/v1/webflow/sites/:site_id/users"
    puts "  GET    /api/v1/webflow/sites/:site_id/users/:user_id"
    puts "  POST   /api/v1/webflow/sites/:site_id/users"
    puts "  PATCH  /api/v1/webflow/sites/:site_id/users/:user_id"
    puts "  DELETE /api/v1/webflow/sites/:site_id/users/:user_id"

    puts "\nComments:"
    puts "  GET    /api/v1/webflow/sites/:site_id/comments"
    puts "  GET    /api/v1/webflow/sites/:site_id/comments/:comment_id"
    puts "  POST   /api/v1/webflow/sites/:site_id/comments"
    puts "  PATCH  /api/v1/webflow/sites/:site_id/comments/:comment_id"
    puts "  DELETE /api/v1/webflow/sites/:site_id/comments/:comment_id"
  end
end
