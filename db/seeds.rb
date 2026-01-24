# frozen_string_literal: true

# Skip clearing existing data to avoid foreign key constraints
puts 'Adding new data to existing database...'

# Create users
puts 'Creating users...'

users = [
  {
    email: 'admin@bullet.com',
    password: 'password123',
    password_confirmation: 'password123',
    name: 'Admin User',
    role: :admin,
    webflow_access: true
  },
  {
    email: 'employee1@bullet.com',
    password: 'password123',
    password_confirmation: 'password123',
    name: 'John Smith',
    role: :contractor,
    webflow_access: false
  },
  {
    email: 'employee2@bullet.com',
    password: 'password123',
    password_confirmation: 'password123',
    name: 'Sarah Johnson',
    role: :contractor,
    webflow_access: false
  },
  {
    email: 'client1@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    name: 'Michael Brown',
    role: :client,
    webflow_access: false
  },
  {
    email: 'client2@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    name: 'Emma Wilson',
    role: :client,
    webflow_access: false
  },
  {
    email: 'client3@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    name: 'David Taylor',
    role: :client,
    webflow_access: false
  }
]

created_users = users.map do |user_attrs|
  User.find_or_create_by(email: user_attrs[:email]) do |user|
    user.assign_attributes(user_attrs)
  end
end

puts "Created #{created_users.count} users"

# Create Window Schedule Repairs
puts 'Creating window schedule repairs...'

# Sample property addresses in London
addresses = [
  '123 Baker Street, Marylebone, London W1U 6TX',
  '45 Kensington High Street, Kensington, London W8 5SA',
  '78 Regent Street, Westminster, London W1B 5AH',
  '12 Oxford Street, Westminster, London W1D 1BS',
  "34 King's Road, Chelsea, London SW3 4UD",
  '56 Fleet Street, City of London, London EC4Y 1HT',
  '89 Piccadilly, Westminster, London W1J 0LL',
  '23 Bond Street, Westminster, London W1S 2PZ',
  '67 Knightsbridge, Westminster, London SW1X 7LA',
  '91 Mayfair, Westminster, London W1K 6LF'
]

# Sample window locations
window_locations = [
  'Living Room - Bay Window',
  'Master Bedroom - Double Glazed',
  'Kitchen - French Doors',
  'Bathroom - Small Window',
  'Dining Room - Picture Window',
  'Guest Bedroom - Single Pane',
  'Study - Sliding Window',
  'Utility Room - Vent Window',
  'Hallway - Stained Glass',
  'Conservatory - Large Windows'
]

# Sample tools with realistic pricing
tools_data = [
  { name: 'Double Glazing Unit 1200x800', price: 450 },
  { name: 'Window Frame Repair Kit', price: 85 },
  { name: 'Weather Stripping (5m)', price: 25 },
  { name: 'Window Hinges (Set of 4)', price: 35 },
  { name: 'Glass Replacement 600x400', price: 120 },
  { name: 'Window Locks (Set of 2)', price: 45 },
  { name: 'Silicone Sealant (Tube)', price: 15 },
  { name: 'Window Handle Replacement', price: 30 },
  { name: 'Draught Excluder (3m)', price: 20 },
  { name: 'Window Cleaning Kit', price: 25 },
  { name: 'Glazing Points (100 pack)', price: 12 },
  { name: 'Window Putty (500g)', price: 18 },
  { name: 'Security Film (1m²)', price: 40 },
  { name: 'Window Tinting Film', price: 35 },
  { name: 'Window Insulation Film', price: 28 }
]

# Sample repair details
repair_details = [
  'Complete window refurbishment including frame repair and new double glazing units',
  'Emergency window replacement due to storm damage',
  'Routine maintenance and weatherproofing',
  'Upgrade to energy-efficient double glazing',
  'Window frame restoration and repainting',
  'Security enhancement with new locks and reinforced glass',
  'Bathroom window replacement with frosted glass',
  'Conservatory window repair and resealing',
  'Period property window restoration',
  'Modern window installation with triple glazing'
]

# Create 20 Window Schedule Repairs
20.times do |i|
  user = created_users.sample
  address = addresses.sample
  flat_number = "#{rand(1..50)}#{('A'..'Z').to_a.sample}"

  wsr = WindowScheduleRepair.create!(
    name: "Window Repair #{i + 1}",
    address: address,
    flat_number: flat_number,
    reference_number: "WRS-#{Time.current.strftime('%Y%m%d')}-#{format('%03d', i + 1)}",
    details: repair_details.sample,
    user: user,
    status: %i[pending approved rejected completed].sample
  )

  # Create 1-4 windows per repair
  window_count = rand(1..4)
  window_count.times do |_j|
    window = wsr.windows.create!(
      location: window_locations.sample
    )

    # Create 1-3 tools per window
    tool_count = rand(1..3)
    tool_count.times do |_k|
      tool_data = tools_data.sample
      window.tools.create!(
        name: tool_data[:name],
        price: tool_data[:price]
      )
    end
  end

  # Recalculate totals after creating windows and tools
  wsr.calculate_totals
  wsr.save!

  puts "Created WSR #{i + 1}: #{wsr.name} with #{wsr.windows.count} windows"
end

# Create additional WRSs for existing test user to ensure API works
puts 'Creating WRSs for existing test user...'
test_user = User.find_by(email: 'test@bullet.co.uk')
if test_user
  5.times do |i|
    wsr = WindowScheduleRepair.create!(
      name: "Test User WRS #{i + 1}",
      address: addresses.sample,
      flat_number: "#{rand(1..50)}#{('A'..'Z').to_a.sample}",
      reference_number: "WRS-#{Time.current.strftime('%Y%m%d')}-#{format('%03d', i + 21)}",
      details: repair_details.sample,
      user: test_user,
      status: %i[pending approved rejected completed].sample
    )

    # Create 1-3 windows per repair
    window_count = rand(1..3)
    window_count.times do |_j|
      window = wsr.windows.create!(
        location: window_locations.sample
      )

      # Create 1-2 tools per window
      tool_count = rand(1..2)
      tool_count.times do |_k|
        tool_data = tools_data.sample
        window.tools.create!(
          name: tool_data[:name],
          price: tool_data[:price]
        )
      end
    end

    # Recalculate totals after creating windows and tools
    wsr.calculate_totals
    wsr.save!

    puts "Created Test User WRS #{i + 1}: #{wsr.name} with #{wsr.windows.count} windows"
  end
else
  puts 'Test user not found, skipping...'
end

puts "\n=== Summary ==="
puts "Users: #{User.count}"
puts "Window Schedule Repairs: #{WindowScheduleRepair.count}"
puts "Windows: #{Window.count}"
puts "Tools: #{Tool.count}"

puts "\n=== Sample Data ==="
puts 'Admin user: admin@bullet.com / password123'
puts 'Contractor users: employee1@bullet.com, employee2@bullet.com / password123'
puts 'Client users: client1@example.com, client2@example.com, client3@example.com / password123'

puts "\n=== Recent WSRs ==="
WindowScheduleRepair.limit(5).each do |wsr|
  puts "#{wsr.name} - #{wsr.address} - Status: #{wsr.status} - Total: £#{wsr.grand_total}"
end

puts "\nSeed data created successfully!"
