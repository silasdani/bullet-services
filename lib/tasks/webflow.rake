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
  task :sync_all_wrs_to_rails => :environment do
    puts "Syncing all WRS to Rails..."
=begin
it = w.list_items({ "offset": 0, "limit": 5 })
Webflow API GET /sites/618ffc83f3028ad35a166db8/collections/619692f4b6773922b32797f2/items/live?offset=0&limit=5 - Status: 200
=> {"items" =>
  [{"id" => "68dfe57b31012c99b176edb8",
    "cmsLocaleId" => nil,
    "lastPublished" => "2025-10-03T15:04:19.329Z",
    "lastUpdated" => "2025-10-03T15:04:19.329Z",
    "createdOn" => "2025-10-03T15:02:19.160Z",
    "isArchived" => false,
    "isDraft" => false,
    "fieldData" =>
     {"accepted-declined" => "#024900",
      "total-incl-vat" => 120,
      "total-exc-vat" => 100,
      "grand-total" => 120,
      "project-summary" => "test1",
      "flat-number" => "56",
      "name" => "test1 - 56",
      "window-location" => "out",
      "window-1-items-2" => "1 set epoxy resin",
      "window-1-items-prices-3" => "100",
      "main-project-image" =>
       {"fileId" => "68dfe57a31012c99b176ed88",
        "url" =>
         "https://cdn.prod.website-files.com/619692f4d2e01f91e2c4c838/68dfe57a31012c99b176ed88_z86q89ujp0occd36cmtgxg2h9qro.jpeg",
        "alt" => nil},
      "slug" => "test1-56-17684f48",
      "accepted-decline" => "Accepted"}},
   {"id" => "68dfb4580855ab76b9c30a3a",
    "cmsLocaleId" => nil,
    "lastPublished" => "2025-10-03T12:59:47.641Z",
    "lastUpdated" => "2025-10-03T12:59:47.641Z",
    "createdOn" => "2025-10-03T11:32:40.721Z",
    "isArchived" => false,
    "isDraft" => false,
    "fieldData" =>
     {"accepted-declined" => "#024900",
      "total-incl-vat" => 30,
      "total-exc-vat" => 25,
      "grand-total" => 30,
      "project-summary" => "test",
      "flat-number" => "157",
      "name" => "test - 157",
      "window-location" => "afara",
      "window-1-items-2" => "Conservation joint repair",
      "window-1-items-prices-3" => "25",
      "main-project-image" =>
       {"fileId" => "68dfb4580855ab76b9c30a35",
        "url" =>
         "https://cdn.prod.website-files.com/619692f4d2e01f91e2c4c838/68dfb4580855ab76b9c30a35_unys3giseyxu400cuqspmc9ldnhl.jpeg",
        "alt" => nil},
      "slug" => "test-157-1bb98ad3",
      "accepted-decline" => "Accepted"}},
   {"id" => "68defd279aa7b1d789c9811f",
    "cmsLocaleId" => nil,
    "lastPublished" => "2025-10-02T22:37:00.518Z",
    "lastUpdated" => "2025-10-02T22:37:00.518Z",
    "createdOn" => "2025-10-02T22:31:03.227Z",
    "isArchived" => false,
    "isDraft" => false,
    "fieldData" =>
     {"accepted-declined" => "#024900",
      "total-incl-vat" => 1452,
      "total-exc-vat" => 1210,
      "grand-total" => 1452,
      "project-summary" => "425100",
      "flat-number" => "Horea 29",
      "name" => "425100 - Horea 29",
      "window-location" => "Rear Elevaton",
      "window-1-items-2" => "New timber sash complete",
      "window-1-items-prices-3" => "1210",
      "main-project-image" =>
       {"fileId" => "68defd279aa7b1d789c98112",
        "url" =>
         "https://cdn.prod.website-files.com/619692f4d2e01f91e2c4c838/68defd279aa7b1d789c98112_4ckuxb1fmttuwv62fg6nuhoafpt4.jpeg",
        "alt" => nil},
      "slug" => "425100-horea-29-e9a155ba",
      "accepted-decline" => "Accepted"}},
   {"id" => "68def3c005d2de6f6ea3eb37",
    "cmsLocaleId" => nil,
    "lastPublished" => "2025-10-02T21:52:24.783Z",
    "lastUpdated" => "2025-10-02T21:52:24.783Z",
    "createdOn" => "2025-10-02T21:50:56.960Z",
    "isArchived" => false,
    "isDraft" => false,
    "fieldData" =>
     {"accepted-declined" => "#024900",
      "total-incl-vat" => 264,
      "total-exc-vat" => 220,
      "grand-total" => 264,
      "project-summary" => "400446",
      "flat-number" => "Liviu Rebreanu - 58",
      "name" => "400446 - Liviu Rebreanu - 58",
      "window-location" => "afară",
      "window-1-items-2" => "1 set epoxy resin\n1000mm timber splice repair",
      "window-1-items-prices-3" => "100\n120",
      "main-project-image" =>
       {"fileId" => "68def3c005d2de6f6ea3eb32",
        "url" =>
         "https://cdn.prod.website-files.com/619692f4d2e01f91e2c4c838/68def3c005d2de6f6ea3eb32_0glfn7at49r2eghbo1yzoq0kafn0.jpeg",
        "alt" => nil},
      "slug" => "400446-liviu-rebreanu-58-e3fa4489",
      "accepted-decline" => "Accepted"}},
   {"id" => "68ded0db87ee32ead1c16492",
    "cmsLocaleId" => nil,
    "lastPublished" => "2025-10-02T19:37:09.060Z",
    "lastUpdated" => "2025-10-02T19:37:09.060Z",
    "createdOn" => "2025-10-02T19:22:03.846Z",
    "isArchived" => false,
    "isDraft" => false,
    "fieldData" =>
     {"accepted-declined" => "#024900",
      "total-incl-vat" => 108,
      "total-exc-vat" => 90,
      "grand-total" => 108,
      "project-summary" => "22 Coleridge HA48GW",
      "flat-number" => "1",
      "name" => "22 Coleridge HA48GW - 1",
      "window-location" => "front",
      "window-1-items-2" => "½ set epoxy resin",
      "window-1-items-prices-3" => "90",
      "main-project-image" =>
       {"fileId" => "68ded0db87ee32ead1c1648d",
        "url" =>
         "https://cdn.prod.website-files.com/619692f4d2e01f91e2c4c838/68ded0db87ee32ead1c1648d_y6peg9gi6wpgobnyksbsgly44wzo.jpeg",
        "alt" => nil},
      "slug" => "22-coleridge-ha48gw-1-6365f21b",
      "accepted-decline" => "Accepted"}}],
 "pagination" => {"limit" => 5, "offset" => 0, "total" => 135}}
=end

    begin
      webflow = WebflowService.new
      total_synced = 0
      offset = 0
      limit = 100

      loop do
        puts "Fetching WRS items (offset: #{offset}, limit: #{limit})..."
        response = webflow.list_items({ offset: offset, limit: limit })

        items = response['items']
        break if items.nil? || items.empty?

        puts "Syncing #{items.length} WRS items to Rails..."

        items.each do |wrs_data|
          puts "Syncing WRS #{wrs_data['id']} to Rails..."

          # Skip if required fields are missing
          if wrs_data['fieldData']['project-summary'].blank? || wrs_data['fieldData']['name'].blank?
            puts "Skipping WRS #{wrs_data['id']} - missing required fields (address or name)"
            next
          end

          # Find or initialize WRS by webflow_item_id
          wrs = WindowScheduleRepair.find_or_initialize_by(webflow_item_id: wrs_data['id'])

          wrs.update(user: User.find_by(email: 'admin@bullet.co.uk')) if wrs.new_record?

          # Update WRS basic information
          wrs.assign_attributes(
            name: wrs_data['fieldData']['name'] || "WRS #{wrs_data['id']}",
            address: wrs_data['fieldData']['project-summary'],
            flat_number: wrs_data['fieldData']['flat-number'],
            details: wrs_data['fieldData']['project-summary'],
            total_vat_included_price: wrs_data['fieldData']['total-incl-vat'],
            total_vat_excluded_price: wrs_data['fieldData']['total-exc-vat'],
            grand_total: wrs_data['fieldData']['grand-total'],
            status: map_webflow_status(wrs_data['fieldData']['accepted-decline']),
            status_color: wrs_data['fieldData']['accepted-declined'],
            slug: wrs_data['fieldData']['slug'] || "wrs-#{wrs_data['id']}"
          )

          # Save the WRS first
          wrs.save!

          # Clear existing windows and recreate them from Webflow data
          wrs.windows.destroy_all

          # Create windows based on available data
          window_data = [
            {
              location: wrs_data['fieldData']['window-location'],
              items: wrs_data['fieldData']['window-1-items-2'],
              prices: wrs_data['fieldData']['window-1-items-prices-3']
            },
            {
              location: wrs_data['fieldData']['window-2-location'],
              items: wrs_data['fieldData']['window-2-items-2'],
              prices: wrs_data['fieldData']['window-2-items-prices-3']
            },
            {
              location: wrs_data['fieldData']['window-3-location'],
              items: wrs_data['fieldData']['window-3-items'],
              prices: wrs_data['fieldData']['window-3-items-prices']
            },
            {
              location: wrs_data['fieldData']['window-4-location'],
              items: wrs_data['fieldData']['window-4-items'],
              prices: wrs_data['fieldData']['window-4-items-prices']
            },
            {
              location: wrs_data['fieldData']['window-5-location'],
              items: wrs_data['fieldData']['window-5-items'],
              prices: wrs_data['fieldData']['window-5-items-prices']
            }
          ]

          window_data.each do |window_info|
            next if window_info[:location].blank?

            window = wrs.windows.create!(
              location: window_info[:location]
            )

            # Parse and create tools for this window
            create_tools_for_window(window, window_info[:items], window_info[:prices])
          end

          puts "WRS #{wrs_data['id']} synced to Rails successfully!"
          total_synced += 1
        end

        # Check if we have more items to fetch
        total_items = response['pagination']['total']
        offset += limit

        if offset >= total_items
          puts "Reached end of items. Total items: #{total_items}"
          break
        end
      end

      puts "All #{total_synced} WRS synced to Rails successfully!"
    rescue WebflowApiError => e
      puts "❌ Webflow API Error: #{e.message}"
      puts "Status Code: #{e.status_code}"
      puts "Response: #{e.response_body}"
    rescue => e
      puts "❌ Unexpected error: #{e.message}"
    end
  end

  private

  def map_webflow_status(webflow_status)
    case webflow_status&.downcase
    when 'accepted'
      'approved'
    when 'declined'
      'rejected'
    else
      'pending'
    end
  end

  def create_tools_for_window(window, items_string, prices_string)
    return if items_string.blank?

    # Split items and prices by newlines
    items = items_string.to_s.split("\n").map(&:strip).reject(&:blank?)
    prices = prices_string.to_s.split("\n").map(&:strip).reject(&:blank?)

    items.each_with_index do |item_name, index|
      price = prices[index]&.to_f || 0.0

      window.tools.create!(
        name: item_name,
        price: price
      )
    end
  end
end
