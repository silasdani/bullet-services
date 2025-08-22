class WebflowCollectionMapperService
  # Maps a WindowScheduleRepair to Webflow collection data
  def self.to_webflow(wrs)
    {
      fieldData: {
        # Basic WRS fields
        name: wrs.name,
        slug: wrs.slug,
        'reference-number': wrs.reference_number,
        'project-summary': wrs.address,
        'flat-number': wrs.flat_number,

        # Window 1
        'main-project-image': wrs.windows[0]&.image_url,
        'window-location': wrs.windows[0]&.location,
        'window-1-items-2': wrs.windows[0]&.tools_list,
        'window-1-items-prices-3': wrs.windows[0]&.tools_prices_list,

        # Window 2
        'window-2': wrs.windows[1]&.image_url,
        'window-2-location': wrs.windows[1]&.location,
        'window-2-items-2': wrs.windows[1]&.tools_list,
        'window-2-items-prices-3': wrs.windows[1]&.tools_prices_list,

        # Window 3
        'window-3-image': wrs.windows[2]&.image_url,
        'window-3-location': wrs.windows[2]&.location,
        'window-3-items': wrs.windows[2]&.tools_list,
        'window-3-items-prices': wrs.windows[2]&.tools_prices_list,

        # Window 4
        'window-4-image': wrs.windows[3]&.image_url,
        'window-4-location': wrs.windows[3]&.location,
        'window-4-items': wrs.windows[3]&.tools_list,
        'window-4-items-prices': wrs.windows[3]&.tools_prices_list,

        # Window 5
        'window-5-image': wrs.windows[4]&.image_url,
        'window-5-location': wrs.windows[4]&.location,
        'window-5-items': wrs.windows[4]&.tools_list,
        'window-5-items-prices': wrs.windows[4]&.tools_prices_list,

        # Totals
        'total-incl-vat': wrs.total_vat_included_price,
        'total-exc-vat': wrs.total_vat_excluded_price,
        'grand-total': wrs.grand_total,
        'accepted-declined': wrs.status_color,
        'accepted-decline': wrs.status
      },
      isArchived: false,
      isDraft: false
    }
  end

  # Maps Webflow collection data back to a WindowScheduleRepair
  def self.from_webflow(webflow_data, existing_wrs = nil)
    field_data = webflow_data['fieldData'] || {}

    wrs = existing_wrs || WindowScheduleRepair.new

    # Update basic WRS fields
    wrs.assign_attributes(
      name: field_data['name'],
      slug: field_data['slug'],
      reference_number: field_data['reference-number'],
      address: field_data['project-summary'],
      flat_number: field_data['flat-number'],
      total_vat_included_price: field_data['total-incl-vat'],
      total_vat_excluded_price: field_data['total-exc-vat'],
      grand_total: field_data['grand-total'],
      status: field_data['accepted-decline'],
      status_color: field_data['accepted-declined']
    )

    # Create/update windows based on Webflow data
    update_windows_from_webflow(wrs, field_data)

    wrs
  end

  private

  def self.update_windows_from_webflow(wrs, field_data)
    # Window 1
    if field_data['window-location'].present?
      window1 = wrs.windows.find_or_initialize_by(location: field_data['window-location'])
      window1.assign_attributes(
        location: field_data['window-location']
      )
      window1.save!

      # Update tools if items are present
      update_window_tools(window1, field_data['window-1-items-2'], field_data['window-1-items-prices-3'])
    end

    # Window 2
    if field_data['window-2-location'].present?
      window2 = wrs.windows.find_or_initialize_by(location: field_data['window-2-location'])
      window2.assign_attributes(
        location: field_data['window-2-location']
      )
      window2.save!

      update_window_tools(window2, field_data['window-2-items-2'], field_data['window-2-items-prices-3'])
    end

    # Window 3
    if field_data['window-3-location'].present?
      window3 = wrs.windows.find_or_initialize_by(location: field_data['window-3-location'])
      window3.assign_attributes(
        location: field_data['window-3-location']
      )
      window3.save!

      update_window_tools(window3, field_data['window-3-items'], field_data['window-3-items-prices'])
    end

    # Window 4
    if field_data['window-4-location'].present?
      window4 = wrs.windows.find_or_initialize_by(location: field_data['window-4-location'])
      window4.assign_attributes(
        location: field_data['window-4-location']
      )
      window4.save!

      update_window_tools(window4, field_data['window-4-items'], field_data['window-4-items-prices'])
    end

    # Window 5
    if field_data['window-5-location'].present?
      window5 = wrs.windows.find_or_initialize_by(location: field_data['window-5-location'])
      window5.assign_attributes(
        location: field_data['window-5-location']
      )
      window5.save!

      update_window_tools(window5, field_data['window-5-items'], field_data['window-5-items-prices'])
    end
  end

  def self.update_window_tools(window, items_text, prices_text)
    return unless items_text.present? && prices_text.present?

    # Parse items and prices (assuming they're comma-separated)
    items = items_text.split(',').map(&:strip)
    prices = prices_text.split(',').map(&:strip).map(&:to_f)

    # Clear existing tools
    window.tools.destroy_all

    # Create new tools
    items.each_with_index do |item_name, index|
      price = prices[index] || 0
      window.tools.create!(
        name: item_name,
        price: price
      )
    end
  end
end
