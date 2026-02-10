# frozen_string_literal: true

# Seed status definitions for WindowScheduleRepair (WorkOrder)
# Colors based on IBM Carbon Design System and Material Design best practices
StatusDefinition.find_or_create_by!(entity_type: 'WindowScheduleRepair', status_key: 'pending') do |sd|
  sd.status_label = 'Pending Approval'
  sd.status_color = '#f1c21b' # Carbon Yellow - indicates warning/needs attention
  sd.display_order = 0
  sd.is_active = true
end

StatusDefinition.find_or_create_by!(entity_type: 'WindowScheduleRepair', status_key: 'approved') do |sd|
  sd.status_label = 'Approved'
  sd.status_color = '#24a148' # Carbon Green - indicates success/completion
  sd.display_order = 1
  sd.is_active = true
end

StatusDefinition.find_or_create_by!(entity_type: 'WindowScheduleRepair', status_key: 'rejected') do |sd|
  sd.status_label = 'Rejected'
  sd.status_color = '#da1e28' # Carbon Red - indicates error/failure
  sd.display_order = 2
  sd.is_active = true
end

StatusDefinition.find_or_create_by!(entity_type: 'WindowScheduleRepair', status_key: 'completed') do |sd|
  sd.status_label = 'Completed'
  sd.status_color = '#24a148' # Carbon Green - indicates success/completion
  sd.display_order = 3
  sd.is_active = true
end

# Seed status definitions for Invoice
# Colors based on IBM Carbon Design System and Material Design best practices
StatusDefinition.find_or_create_by!(entity_type: 'Invoice', status_key: 'draft') do |sd|
  sd.status_label = 'Draft'
  sd.status_color = '#6f6f6f' # Carbon Gray - indicates not started/draft state
  sd.display_order = 0
  sd.is_active = true
end

StatusDefinition.find_or_create_by!(entity_type: 'Invoice', status_key: 'sent') do |sd|
  sd.status_label = 'Sent'
  sd.status_color = '#0043ce' # Carbon Blue - indicates informational/actionable state
  sd.display_order = 1
  sd.is_active = true
end

StatusDefinition.find_or_create_by!(entity_type: 'Invoice', status_key: 'viewed') do |sd|
  sd.status_label = 'Viewed'
  sd.status_color = '#1976d2' # Material Blue 700 - lighter blue for viewed state
  sd.display_order = 2
  sd.is_active = true
end

StatusDefinition.find_or_create_by!(entity_type: 'Invoice', status_key: 'paid') do |sd|
  sd.status_label = 'Paid'
  sd.status_color = '#24a148' # Carbon Green - indicates success/completion
  sd.display_order = 3
  sd.is_active = true
end

StatusDefinition.find_or_create_by!(entity_type: 'Invoice', status_key: 'overdue') do |sd|
  sd.status_label = 'Overdue'
  sd.status_color = '#da1e28' # Carbon Red - indicates error/urgent action required
  sd.display_order = 4
  sd.is_active = true
end

StatusDefinition.find_or_create_by!(entity_type: 'Invoice', status_key: 'void') do |sd|
  sd.status_label = 'Void'
  sd.status_color = '#6f6f6f' # Carbon Gray - indicates inactive/disabled state
  sd.display_order = 5
  sd.is_active = true
end

StatusDefinition.find_or_create_by!(entity_type: 'Invoice', status_key: 'voided') do |sd|
  sd.status_label = 'Voided'
  sd.status_color = '#6f6f6f' # Carbon Gray - indicates inactive/disabled state
  sd.display_order = 6
  sd.is_active = true
end

puts '✅ Status definitions seeded successfully'
