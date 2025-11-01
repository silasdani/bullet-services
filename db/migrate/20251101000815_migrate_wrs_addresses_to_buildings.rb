class MigrateWrsAddressesToBuildings < ActiveRecord::Migration[8.0]
  def up
    # Skip if no WRS exist (use table name to avoid model loading issues)
    return unless connection.table_exists?('window_schedule_repairs')

    # Check if there are any WRS records
    wrs_count = connection.execute("SELECT COUNT(*) as count FROM window_schedule_repairs").first
    return if wrs_count.nil? || wrs_count['count'].to_i == 0

    # Reference models using string to avoid loading issues
    wrs_class = Class.new(ActiveRecord::Base) do
      self.table_name = 'window_schedule_repairs'
    end

    building_class = Class.new(ActiveRecord::Base) do
      self.table_name = 'buildings'
    end

    # Group WRS by normalized address (case-insensitive, trimmed)
    address_groups = wrs_class.where.not(address: [nil, ''])
                              .all
                              .group_by { |wrs| (wrs.read_attribute(:address) || '').to_s.strip.downcase }

    address_groups.each do |normalized_address, wrs_list|
      # Use the first WRS address as the source (they should all be the same after normalization)
      source_address = wrs_list.first.read_attribute(:address)

      # Try to parse address components from the string
      # Format might be: "buildingNumber, streetAddress, postcode" or just a single string
      address_parts = parse_address(source_address)

      # Create Building record with address fields directly
      building_name = address_parts[:name] || address_parts[:building_number] || source_address

      # Find or create building by street, city, and zipcode (unique address)
      building = building_class.find_or_initialize_by(
        street: address_parts[:street] || source_address,
        city: address_parts[:city] || '',
        zipcode: address_parts[:zipcode] || ''
      )

      # Set other fields
      building.name = building_name
      building.country = address_parts[:country] || 'UK'
      building.save!

      # Update all WRS records with this address to point to this building
      wrs_class.where(id: wrs_list.map(&:id)).update_all(building_id: building.id)
    end

    # Handle WRS with blank/null addresses
    wrs_without_address = wrs_class.where(address: [nil, ''])
                                     .or(wrs_class.where('address IS NULL'))
                                     .where(building_id: nil)

    if wrs_without_address.exists?
      # Create a default building for orphaned WRS
      default_building = building_class.find_or_initialize_by(
        name: 'Unknown Building',
        street: 'Address Not Provided',
        city: '',
        country: 'UK',
        zipcode: ''
      )
      default_building.save!

      wrs_without_address.update_all(building_id: default_building.id)
    end
  end

  def down
    # Remove building_id references
    connection.execute("UPDATE window_schedule_repairs SET building_id = NULL")

    # Note: We don't delete Address/Building records here as they might have been
    # created manually. A separate cleanup migration can be created if needed.
  end

  private

  def parse_address(address_string)
    return {} if address_string.blank?

    # Common patterns:
    # 1. "123 Main Street, London, SW1A 1AA" (building, street, city, postcode)
    # 2. "123, Main Street, SW1A 1AA" (building, street, postcode)
    # 3. "Main Street, SW1A 1AA" (street, postcode)
    # 4. "123 Main Street" (just address)

    parts = address_string.split(',').map(&:strip)

    result = {}

    # Try to identify postcode (UK format: letters + numbers + optional space + letters + numbers)
    uk_postcode_pattern = /\b[A-Z]{1,2}\d{1,2}[A-Z]?\s?\d[A-Z]{2}\b/i
    postcode_match = address_string.match(uk_postcode_pattern)

    if postcode_match
      result[:zipcode] = postcode_match[0].upcase
      # Remove postcode from parts
      parts = address_string.gsub(uk_postcode_pattern, '').split(',').map(&:strip).reject(&:blank?)
    end

    # Determine components based on number of parts
    case parts.length
    when 1
      # Single part - likely just street or building + street
      if parts[0] =~ /^\d+/
        # Starts with number - likely building number + street
        match = parts[0].match(/^(\d+[A-Z]?)\s+(.+)/)
        if match
          result[:building_number] = match[1]
          result[:street] = match[2]
        else
          result[:street] = parts[0]
        end
      else
        result[:street] = parts[0]
      end
    when 2
      # Two parts - likely building, street OR street, city
      if parts[0] =~ /^\d+/
        result[:building_number] = parts[0]
        result[:street] = parts[1]
      else
        result[:street] = parts[0]
        result[:city] = parts[1]
      end
    when 3..Float::INFINITY
      # Three or more parts - likely building, street, city, etc.
      if parts[0] =~ /^\d+/
        result[:building_number] = parts[0]
        result[:street] = parts[1]
        result[:city] = parts[2] if parts[2].present?
      else
        result[:street] = parts[0]
        result[:city] = parts[1] if parts[1].present?
      end

      # Country might be in last part if not postcode
      if parts.length > 2 && !postcode_match
        potential_country = parts.last
        if potential_country.length > 2 && !potential_country.match?(/^\d/)
          result[:country] = potential_country
        end
      end
    end

    # Construct a name from building number and street if available
    if result[:building_number] && result[:street]
      result[:name] = "#{result[:building_number]} #{result[:street]}"
    elsif result[:street]
      result[:name] = result[:street]
    end

    result
  end
end
