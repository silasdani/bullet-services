class WrsSyncService
  attr_reader :total_synced, :total_skipped

  def initialize(admin_user = nil)
    @admin_user = admin_user
    @total_synced = 0
    @total_skipped = 0
    @processed_count = 0
  end

  # Process a single WRS item (used by rake task)
  def sync_single(wrs_data)
    process_wrs_item(wrs_data)
  end

  # Process multiple WRS items in bulk
  def sync_batch(wrs_items)
    total_items = wrs_items.size
    puts "\n🔄 Starting sync of #{total_items} WRS items..."

    wrs_items.each_with_index do |wrs_data, index|
      process_wrs_item(wrs_data)
      @processed_count += 1
      render_progress(@processed_count, total_items)
    end

    puts "\n\n✨ Sync complete! Synced: #{@total_synced}, Skipped: #{@total_skipped}"
    { synced: @total_synced, skipped: @total_skipped }
  end

  private

  def process_wrs_item(wrs_data)
    begin
      # Skip if required fields are missing
      if wrs_data["fieldData"]["project-summary"].blank? || wrs_data["fieldData"]["name"].blank?
        @total_skipped += 1
        return { success: false, reason: "missing_required_fields" }
      end

      # Find or initialize WRS by webflow_item_id
      wrs = WindowScheduleRepair.find_or_initialize_by(webflow_item_id: wrs_data["id"])

      # Set flag to prevent auto-sync back to Webflow (prevent circular sync loop)
      wrs.skip_webflow_sync = true
      Rails.logger.debug "WrsSyncService: Syncing from Webflow, skip_webflow_sync=true to prevent circular loop"

      # Set user for new records
      wrs.user = @admin_user if wrs.new_record? && @admin_user

      # Update WRS basic information
      status_color = wrs_data["fieldData"]["accepted-declined"]
      field_data = wrs_data["fieldData"]

      # Extract price fields with fallback options
      total_incl_vat = wf_first(field_data, "total-incl-vat", "total_incl_vat", "totalInclVat")
      total_excl_vat = wf_first(field_data, "total-exc-vat", "total-excl-vat", "total_exc_vat", "totalExcVat")
      grand_total_val = wf_first(field_data, "grand-total", "grand_total", "grandTotal")

      # Debug output for price fields
      if total_incl_vat.nil? && total_excl_vat.nil?
        puts "   ⚠️  Warning: No VAT prices found in fieldData for WRS #{wrs_data['id']}"
        puts "      Available fields: #{field_data.keys.select { |k| k.include?('total') || k.include?('vat') }.join(', ')}"
      end

      wrs.assign_attributes(
        name: field_data["name"] || "WRS #{wrs_data['id']}",
        address: field_data["project-summary"],
        flat_number: field_data["flat-number"],
        details: field_data["project-summary"],
        total_vat_included_price: total_incl_vat&.to_f || 0.0,
        total_vat_excluded_price: total_excl_vat&.to_f || 0.0,
        grand_total: grand_total_val&.to_f || 0.0,
        status: map_status_color_to_status(status_color),
        status_color: status_color,
        slug: field_data["slug"] || "wrs-#{wrs_data['id']}",
        last_published: wrs_data["lastPublished"],
        is_draft: wrs_data["isDraft"],
        is_archived: wrs_data["isArchived"],
        webflow_main_image_url: (field_data["main-project-image"] && field_data["main-project-image"]["url"])
      )

      # Apply Webflow timestamps to the record if present
      wrs.created_at = Time.parse(wrs_data["createdOn"]) rescue wrs.created_at
      wrs.updated_at = Time.parse(wrs_data["lastUpdated"]) rescue wrs.updated_at

      # Save the WRS first
      wrs.save!

      # Bulk delete existing tools and windows (in correct order)
      # First delete all tools for this WRS
      Tool.joins(:window).where(windows: { window_schedule_repair_id: wrs.id }).delete_all
      # Then delete all windows
      wrs.windows.delete_all

      # Prepare window data
      window_data = prepare_window_data(wrs_data["fieldData"], wrs_data)

      # Bulk create windows and tools
      created_stats = create_windows_and_tools_bulk(wrs, window_data)

      @total_synced += 1
      { success: true, wrs_id: wrs.id, stats: created_stats }
    rescue => e
      @total_skipped += 1
      puts "❌ Error processing WRS item #{wrs_data['id']}: #{e.class} - #{e.message}"
      e.backtrace.first(3).each { |line| puts "   ↳ #{line}" }
      { success: false, error: e.message }
    end
  end

  def render_progress(processed, total)
    width = 40
    ratio = [ [ processed.to_f / [ total, 1 ].max, 0 ].max, 1 ].min
    filled = (ratio * width).floor
    bar = "[" + ("#" * filled) + ("-" * (width - filled)) + "]"
    percent = (ratio * 100).round(1)
    print "\r#{bar} #{percent}% (#{processed}/#{total})"
    $stdout.flush
  end

  def wf_first(field_data, *keys)
    keys.each do |k|
      v = field_data[k]
      return v if v.present?
    end
    nil
  end

  def map_status_color_to_status(status_color)
    case status_color&.downcase
    when "#024900" # Green - accepted
      "approved"
    when "#750002", "#740000" # Dark colors - rejected
      "rejected"
    else
      "pending"
    end
  end

  def prepare_window_data(field_data, wrs_data)
    base_image_url = (field_data["main-project-image"] && field_data["main-project-image"]["url"])
    windows = []

    # Check for windows 1-10 to handle cases where windows don't start from 1
    (1..10).each do |idx|
      # For window 1, use "window-location", for others use "window-#{idx}-location"
      location_key = idx == 1 ? "window-location" : "window-#{idx}-location"
      location = field_data[location_key]
      next if location.blank?

      # Try multiple variations of items field names
      items_keys = if idx == 1
        [ "window-1-items-2", "window-1-items", "window-items" ]
      else
        [ "window-#{idx}-items-2", "window-#{idx}-items" ]
      end

      # Try multiple variations of prices field names
      prices_keys = if idx == 1
        [ "window-1-items-prices-3", "window-1-items-prices", "window-items-prices" ]
      else
        [ "window-#{idx}-items-prices-3", "window-#{idx}-items-prices" ]
      end

      items_val = wf_first(field_data, *items_keys)
      prices_val = wf_first(field_data, *prices_keys)

      # Handle image URL - can be from main-project-image (window 1) or window-specific field
      image_val = if idx == 1
        base_image_url
      else
        # Try both "window-#{idx}-image" and "window-#{idx}-image-url"
        field_data["window-#{idx}-image"] || field_data["window-#{idx}-image-url"]
      end

      # Extract URL from image value (can be a Hash with url/fileId or a string)
      image_url = if image_val.is_a?(Hash)
        image_val["url"]
      else
        image_val
      end

      windows << {
        location: location,
        items: items_val,
        prices: prices_val,
        image_url: image_url,
        created_on: wrs_data["createdOn"],
        last_updated: wrs_data["lastUpdated"]
      }
    end

    windows
  end

  def create_windows_and_tools_bulk(wrs, window_data)
    return { windows_created: 0, tools_created: 0, mismatched_rows: 0 } if window_data.empty?

    # Bulk create windows
    windows_to_create = window_data.map do |window_info|
      {
        window_schedule_repair_id: wrs.id,
        location: window_info[:location],
        webflow_image_url: window_info[:image_url],
        created_at: (Time.parse(window_info[:created_on]) rescue Time.current),
        updated_at: (Time.parse(window_info[:last_updated]) rescue Time.current)
      }
    end

    # Use insert_all for bulk window creation
    Window.insert_all(windows_to_create, returning: [ :id, :location ])

    # Get the created windows
    created_windows = Window.where(window_schedule_repair_id: wrs.id)
                           .where(location: window_data.map { |w| w[:location] })
                           .index_by(&:location)

    # Bulk create tools
    tools_to_create = []
    mismatches = 0
    window_data.each do |window_info|
      window = created_windows[window_info[:location]]
      next unless window

      items = parse_items(window_info[:items])
      prices = parse_prices(window_info[:prices])

      # Normalize lengths; log mismatches
      if items.length != prices.length && !prices.empty?
        mismatches += (items.length - prices.length).abs
      end
      if prices.length < items.length
        prices += Array.new(items.length - prices.length, 0.0)
      elsif prices.length > items.length
        prices = prices.first(items.length)
      end

      items.each_with_index do |item_name, index|
        price = prices[index] || 0.0
        tools_to_create << {
          window_id: window.id,
          name: item_name,
          price: price,
          created_at: (Time.parse(window_info[:created_on]) rescue Time.current),
          updated_at: (Time.parse(window_info[:last_updated]) rescue Time.current)
        }
      end
    end

    # Bulk insert tools if any
    Tool.insert_all(tools_to_create) if tools_to_create.any?

    { windows_created: created_windows.size, tools_created: tools_to_create.size, mismatched_rows: mismatches }
  end

  def parse_items(items_string)
    return [] if items_string.blank?
    items_string.to_s.split("\n").map(&:strip).reject(&:blank?)
  end

  def parse_prices(prices_string)
    return [] if prices_string.blank?
    prices_string.to_s.split("\n").map(&:strip).reject(&:blank?).map(&:to_f)
  end
end


=begin
# for Cursor to work
[1] pry(main)> w = WebflowService.new
=> #<WebflowService:0x0000000127d1dfd0
 @api_key="ab123002613835a668a562bae28ce44ca6a31498a8983801ee2716437d7fc741",
 @collection_id="619692f4b6773922b32797f2",
 @rate_limit_requests=[],
 @site_id="618ffc83f3028ad35a166db8">
[2] pry(main)> w.get_item('68d2a113b8db547c6f04e825')
Webflow API GET /sites/618ffc83f3028ad35a166db8/collections/619692f4b6773922b32797f2/items/68d2a113b8db547c6f04e825 - Status: 200
=> {"id" => "68d2a113b8db547c6f04e825",
 "cmsLocaleId" => nil,
 "lastPublished" => "2025-10-07T12:24:15.867Z",
 "lastUpdated" => "2025-10-07T12:18:57.585Z",
 "createdOn" => "2025-09-23T13:30:59.224Z",
 "isArchived" => false,
 "isDraft" => false,
 "fieldData" =>
  {"accepted-declined" => "#024900",
   "grand-total" => 1232.4,
   "project-summary" => "SW5 9TU",
   "flat-number" => "Basement Flat building no 49",
   "name" => "Basement Flat no 49",
   "window-3-location" => "Rear left basement door and window ",
   "window-3-items" => "½ set epoxy resin",
   "window-4-location" => "Rear right basement door and window ",
   "window-4-items" => "New timber cill complete",
   "window-4-items-prices" => "221",
   "window-4-image" =>
    {"fileId" => "68d29931381c6069c31fa959",
     "url" => "https://cdn.prod.website-files.com/619692f4d2e01f91e2c4c838/68d29931381c6069c31fa959_uy8z65v74dq6f5t370sjvskxakbo.jpeg",
     "alt" => nil},
   "window-3-image" =>
    {"fileId" => "68d29931381c6069c31fa961",
     "url" => "https://cdn.prod.website-files.com/619692f4d2e01f91e2c4c838/68d29931381c6069c31fa961_pag3yhd9hii0d9vdtpk6jt30c6i5.jpeg",
     "alt" => nil},
   "slug" => "47-49-pennywern-road-6af89489-cc3d7",
   "window-3-items-prices" => "60",
   "total-exc-vat" => 281,
   "total-incl-vat" => 337.2,
   "accepted-decline" => "Accepted"}}

w = WebflowService.new
syncer = WrsSyncService.new(User.admin.first)
witem = w.get_item('67044f41c7f9a70ef7654851')
syncer.sync_single(witem)
=end
