# frozen_string_literal: true

namespace :webflow do
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
  task :sync_all_wrs_to_rails do
    puts "Syncing all WRS to Rails..."

    begin
      webflow = WebflowService.new
      wrs = webflow.list_wrs

      if wrs['wrs']&.any?
        puts "Syncing #{wrs['wrs'].length} WRS to Rails..."

        wrs['wrs'].each do |wrs|
          puts "Syncing WRS #{wrs['id']} to Rails..."

          wrs = Wrs.find_or_initialize_by(reference_number: wrs['reference_number'])

          wrs.update(
            name: wrs['name'],
            address: wrs['address'],
            flat_number: wrs['flat_number'],
            details: wrs['details'],
            total_vat_included_price: wrs['total_incl_vat'],
            total_vat_excluded_price: wrs['total_exc_vat'],
            grand_total: wrs['grand_total'],
            status: wrs['accepted_decline'],
            status_color: wrs['accepted_declined']
          )

          window1 = wrs.windows.find_or_initialize_by(location: wrs['window_location'])
          window2 = wrs.windows.find_or_initialize_by(location: wrs['window_2_location'])
          window3 = wrs.windows.find_or_initialize_by(location: wrs['window_3_location'])
          window4 = wrs.windows.find_or_initialize_by(location: wrs['window_4_location'])
          window5 = wrs.windows.find_or_initialize_by(location: wrs['window_5_location'])

          window1.update(
            location: wrs['window_location'],
            tools_list: wrs['window_1_items_2'],
            tools_prices_list: wrs['window_1_items_prices_3']
          )


          window2.update(
            location: wrs['window_2_location'],
            tools_list: wrs['window_2_items_2'],
            tools_prices_list: wrs['window_2_items_prices_3']
          )

          window3.update(
            location: wrs['window_3_location'],
            tools_list: wrs['window_3_items'],
            tools_prices_list: wrs['window_3_items_prices']
          )

          window4.update(
            location: wrs['window_4_location'],
            tools_list: wrs['window_4_items'],
            tools_prices_list: wrs['window_4_items_prices']
          )

          window5.update(
            location: wrs['window_5_location'],
            tools_list: wrs['window_5_items'],
            tools_prices_list: wrs['window_5_items_prices']
          )

          wrs.save!

          puts "WRS #{wrs['id']} synced to Rails successfully!"
        end
      end

      puts "All WRS synced to Rails successfully!"
    end

    rescue WebflowApiError => e
      puts "❌ Webflow API Error: #{e.message}"
      puts "Status Code: #{e.status_code}"
      puts "Response: #{e.response_body}"
    rescue => e
      puts "❌ Unexpected error: #{e.message}"
    end
  end
end
