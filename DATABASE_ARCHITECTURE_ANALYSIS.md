# Database Architecture Analysis & Recommendations

## Executive Summary

This document provides a comprehensive analysis of the current database schema and recommendations for improvements if rebuilding from scratch. The analysis focuses on scalability, maintainability, SOLID principles, and simplicity.

---

## Current Schema Overview

### Core Entities
- **Users**: Authentication, roles (client, contractor, admin, surveyor)
- **Buildings**: Physical locations with geocoding
- **WindowScheduleRepairs (WRS)**: Main work order entity
- **Windows**: Individual windows within a WRS
- **Tools**: Repair items/tasks for windows
- **CheckIns**: Time tracking for contractors
- **OngoingWorks**: Work progress updates
- **Notifications**: User notifications
- **Invoices**: Billing records
- **Freshbooks Integration**: External invoicing sync

---

## Critical Issues & Recommendations

### 1. **Data Type Inconsistencies**

#### Issue
- `tools.price` is `integer` but should be `decimal` for precision
- Price calculations use `.to_f` conversions, indicating type mismatches
- Currency amounts stored as `decimal(10,2)` but tool prices as integers

#### Recommendation
```ruby
# Migration
change_column :tools, :price, :decimal, precision: 10, scale: 2, null: false, default: 0.0

# Model
class Tool < ApplicationRecord
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
```

**Impact**: Prevents rounding errors, ensures consistency across price calculations.

---

### 2. **Redundant Fields**

#### Issues Found

**A. Price Redundancy**
- `window_schedule_repairs.grand_total` = `total_vat_included_price` (always identical)
- Recommendation: Remove `grand_total`, use `total_vat_included_price` directly

**B. Notification Status Redundancy**
- `notifications.read` (boolean) and `read_at` (timestamp) serve the same purpose
- Recommendation: Remove `read` boolean, derive from `read_at.present?`

**C. Address Duplication**
- `window_schedule_repairs.address` duplicates `buildings` address data
- Recommendation: Remove `address` from WRS, use `building.full_address` or denormalize only if performance critical

#### Implementation
```ruby
# Remove redundant fields
remove_column :window_schedule_repairs, :grand_total
remove_column :window_schedule_repairs, :address
remove_column :notifications, :read

# Update models
class Notification < ApplicationRecord
  def read?
    read_at.present?
  end
end
```

---

### 3. **Missing Normalization**

#### A. Webflow Integration Fields

**Current**: Webflow fields scattered across tables (`webflow_item_id`, `webflow_main_image_url`, `webflow_created_on`, etc.)

**Recommendation**: Extract to a polymorphic `webflow_syncs` table:

```ruby
create_table "webflow_syncs" do |t|
  t.references :syncable, polymorphic: true, null: false, index: true
  t.string "webflow_item_id"
  t.string "webflow_collection_id"
  t.string "webflow_main_image_url"
  t.string "webflow_created_on"
  t.string "webflow_published_on"
  t.string "webflow_updated_on"
  t.datetime "last_synced_at"
  t.jsonb "sync_metadata"
  t.timestamps
end

# Usage
class WindowScheduleRepair < ApplicationRecord
  has_one :webflow_sync, as: :syncable, dependent: :destroy
end
```

**Benefits**: 
- Single source of truth for Webflow integration
- Easier to add Webflow sync to other models
- Cleaner model code

#### B. Decision/Acceptance Fields

**Current**: Decision fields mixed into `window_schedule_repairs`:
- `decision_at`, `decision`, `decision_client_email`, `decision_client_name`
- `terms_accepted_at`, `terms_version`

**Recommendation**: Extract to `wrs_decisions` table:

```ruby
create_table "wrs_decisions" do |t|
  t.references :window_schedule_repair, null: false, foreign_key: true, index: { unique: true }
  t.string "decision", null: false # approved, rejected
  t.datetime "decision_at", null: false
  t.string "client_email"
  t.string "client_name"
  t.datetime "terms_accepted_at"
  t.string "terms_version"
  t.jsonb "decision_metadata"
  t.timestamps
end
```

**Benefits**: 
- Clear separation of concerns
- Easier to query decision history
- Can support multiple decisions per WRS if needed

#### C. Status Management

**Current**: Multiple status-related fields:
- `window_schedule_repairs.status` (enum)
- `window_schedule_repairs.status_color` (string)
- `invoices.status` + `invoices.final_status` + `invoices.status_color`

**Performance Concern**: Status is queried frequently (e.g., `.contractor_visible_status`, `where(status: ...)` in policies, scopes, filters). Requiring a JOIN to `status_definitions` for every query would significantly impact performance.

**Recommendation**: **Hybrid Approach** - Keep status as enum/integer for fast queries, use lookup table only for metadata:

```ruby
# 1. Keep status as enum/integer on main tables (NO CHANGE)
# window_schedule_repairs.status remains as integer enum
# invoices.status remains as string/enum

# 2. Create status_definitions lookup table for METADATA ONLY
create_table "status_definitions" do |t|
  t.string "entity_type", null: false # 'WindowScheduleRepair', 'Invoice'
  t.string "status_key", null: false  # 'pending', 'approved', etc.
  t.string "status_label", null: false # 'Pending Approval', 'Approved', etc.
  t.string "status_color", null: false # '#FF5733', etc.
  t.integer "display_order", default: 0
  t.boolean "is_active", default: true
  t.timestamps
end

add_index :status_definitions, [:entity_type, :status_key], unique: true

# 3. Optionally denormalize status_color for display performance
# Keep status_color on main table if frequently displayed in lists
# Or remove it and fetch from lookup table only when needed
```

**Implementation Pattern**:

```ruby
# Model concern for status metadata
module StatusMetadata
  extend ActiveSupport::Concern
  
  included do
    # Cache status definitions in memory (rarely changes)
    def self.status_definitions_cache
      @status_definitions_cache ||= begin
        Rails.cache.fetch("status_definitions/#{name}", expires_in: 1.hour) do
          StatusDefinition.where(entity_type: name, is_active: true)
                          .index_by(&:status_key)
        end
      end
    end
    
    def status_metadata
      self.class.status_definitions_cache[status.to_s]
    end
    
    def status_label
      status_metadata&.status_label || status.to_s.humanize
    end
    
    def status_color
      status_metadata&.status_color || '#CCCCCC'
    end
  end
end

# Usage in models
class WindowScheduleRepair < ApplicationRecord
  include StatusMetadata
  
  enum :status, pending: 0, approved: 1, rejected: 2, completed: 3
  
  # Fast queries still work without JOIN
  scope :contractor_visible_status, -> { 
    where(status: statuses.values_at(:pending, :approved, :rejected)) 
  }
end

# Usage in serializers/views
# Fast: No JOIN needed for filtering
WindowScheduleRepair.where(status: :approved)

# Metadata fetched from cache (no JOIN)
wrs.status_label  # => "Approved"
wrs.status_color  # => "#28a745"
```

**Performance Comparison**:

```ruby
# ❌ BAD: Requires JOIN on every query
WindowScheduleRepair.joins(:status_definition)
                    .where(status_definitions: { status_key: 'approved' })
# SQL: SELECT ... FROM window_schedule_repairs 
#      INNER JOIN status_definitions ON ...
#      WHERE status_definitions.status_key = 'approved'

# ✅ GOOD: Fast integer comparison, no JOIN
WindowScheduleRepair.where(status: :approved)
# SQL: SELECT ... FROM window_schedule_repairs 
#      WHERE status = 1

# Metadata fetched from cached lookup (no JOIN)
wrs.status_label  # Fetched from in-memory cache
```

**Benefits**:
- ✅ **Fast queries**: No JOIN required for status filtering (most common operation)
- ✅ **Centralized metadata**: Colors, labels, display order in one place
- ✅ **Easy to add statuses**: Update lookup table, no migration needed
- ✅ **Cached**: Status definitions cached in memory (rarely changes)
- ✅ **Backward compatible**: Existing queries continue to work

**Alternative: Denormalize status_color**

If `status_color` is frequently displayed in lists and you want to avoid even the cache lookup:

```ruby
# Keep status_color on main table, sync from lookup table
class WindowScheduleRepair < ApplicationRecord
  before_save :sync_status_color
  
  private
  
  def sync_status_color
    self.status_color = status_metadata&.status_color if status_changed?
  end
end
```

This gives you:
- Fast queries (no JOIN)
- Fast display (no cache lookup)
- Single source of truth (lookup table)
- Automatic sync when status changes

**Recommended**: Use cached lookup approach first, denormalize only if profiling shows cache lookup is a bottleneck.

---

### 4. **Missing Audit Trail**

#### Issue
No tracking of who created/modified records (except `work_order_assignments.assigned_by_user_id`)

#### Recommendation
Add `audit_fields` concern and migration:

```ruby
# Migration
add_column :window_schedule_repairs, :created_by_id, :bigint
add_column :window_schedule_repairs, :updated_by_id, :bigint
add_foreign_key :window_schedule_repairs, :users, column: :created_by_id
add_foreign_key :window_schedule_repairs, :users, column: :updated_by_id

# Apply to all main tables
%w[buildings windows tools invoices check_ins ongoing_works].each do |table|
  add_column table, :created_by_id, :bigint
  add_column table, :updated_by_id, :bigint
  add_foreign_key table, :users, column: :created_by_id
  add_foreign_key table, :users, column: :updated_by_id
end

# Concern
module Auditable
  extend ActiveSupport::Concern
  
  included do
    belongs_to :created_by, class_name: 'User', optional: true
    belongs_to :updated_by, class_name: 'User', optional: true
    
    before_create :set_created_by
    before_update :set_updated_by
  end
  
  private
  
  def set_created_by
    self.created_by_id ||= Current.user&.id
  end
  
  def set_updated_by
    self.updated_by_id = Current.user&.id if Current.user
  end
end
```

**Benefits**: 
- Compliance and debugging
- User accountability
- Historical tracking

---

### 5. **Inconsistent Soft Deletes**

#### Issue
Only some tables have `deleted_at`:
- ✅ `users`, `buildings`, `window_schedule_repairs`
- ❌ `windows`, `tools`, `check_ins`, `ongoing_works`, `invoices`

#### Recommendation
**Option A**: Add soft deletes to all tables (if business requires recovery)
**Option B**: Only soft delete top-level entities (`users`, `buildings`, `wrs`), hard delete children

**Recommended**: Option B (simpler, clearer)

```ruby
# Only soft delete:
# - users
# - buildings  
# - window_schedule_repairs
# - invoices (for audit trail)

# Hard delete (cascade):
# - windows, tools, check_ins, ongoing_works
```

---

### 6. **Missing Indexes**

#### Current Gaps

**A. Composite Indexes for Common Queries**
```ruby
# window_schedule_repairs
add_index :window_schedule_repairs, [:building_id, :status, :deleted_at]
add_index :window_schedule_repairs, [:user_id, :status, :created_at]

# check_ins
add_index :check_ins, [:window_schedule_repair_id, :action, :timestamp]

# notifications
add_index :notifications, [:user_id, :read_at, :created_at]
add_index :notifications, [:window_schedule_repair_id, :notification_type]

# ongoing_works
add_index :ongoing_works, [:window_schedule_repair_id, :work_date, :user_id]
```

**B. Partial Indexes for Performance**
```ruby
# Only index active records
add_index :window_schedule_repairs, [:status], 
  where: "deleted_at IS NULL AND is_draft = false"

# Only index unread notifications
add_index :notifications, [:user_id, :created_at], 
  where: "read_at IS NULL"
```

---

### 7. **Price Calculation Architecture**

#### Issues
- Hardcoded VAT rate (20%) in `WrsCalculations`
- Tool prices duplicated in Ruby and JavaScript
- No price history/versioning
- No support for different VAT rates

#### Recommendations

**A. Extract VAT Configuration**
```ruby
# config/application.rb or initializer
VAT_RATE = ENV.fetch('VAT_RATE', '0.20').to_f

# Or use a settings table
create_table "system_settings" do |t|
  t.string "key", null: false, unique: true
  t.text "value"
  t.timestamps
end

# Usage
SystemSetting.vat_rate # => 0.20
```

**B. Create Price History Table**
```ruby
create_table "price_snapshots" do |t|
  t.references :priceable, polymorphic: true, null: false
  t.decimal "subtotal", precision: 10, scale: 2
  t.decimal "vat_rate", precision: 5, scale: 4
  t.decimal "vat_amount", precision: 10, scale: 2
  t.decimal "total", precision: 10, scale: 2
  t.datetime "snapshot_at", null: false
  t.jsonb "line_items" # Store tool prices at time of snapshot
  t.timestamps
end

# Usage: Snapshot prices when WRS is approved
class WindowScheduleRepair < ApplicationRecord
  has_many :price_snapshots, as: :priceable
  
  def snapshot_prices!
    price_snapshots.create!(
      subtotal: total_vat_excluded_price,
      vat_rate: VAT_RATE,
      vat_amount: vat_amount,
      total: total_vat_included_price,
      snapshot_at: Time.current,
      line_items: windows.map { |w| { window_id: w.id, tools: w.tools.map { |t| { name: t.name, price: t.price } } } }
    )
  end
end
```

**C. Extract Tool Catalog**
```ruby
create_table "tool_catalog" do |t|
  t.string "name", null: false, unique: true
  t.decimal "default_price", precision: 10, scale: 2, null: false
  t.text "description"
  t.boolean "is_active", default: true
  t.integer "display_order", default: 0
  t.timestamps
end

# Update Tool model
class Tool < ApplicationRecord
  belongs_to :tool_catalog, optional: true
  
  def price
    super || tool_catalog&.default_price || 0
  end
end
```

**Benefits**:
- Single source of truth for tool prices
- Easy to update prices globally
- Price history for auditing
- Support for multiple VAT rates

---

### 8. **Check-In Concurrency**

#### Issue
`check_ins` uses `lock_version` for optimistic locking, but the active check-in logic is complex.

#### Recommendation
**Option A**: Simplify with a state machine
```ruby
# Add state to window_schedule_repairs or create work_sessions table
create_table "work_sessions" do |t|
  t.references :user, null: false
  t.references :window_schedule_repair, null: false
  t.datetime "checked_in_at", null: false
  t.datetime "checked_out_at"
  t.decimal "latitude", precision: 10, scale: 7
  t.decimal "longitude", precision: 10, scale: 7
  t.string "address"
  t.timestamps
end

add_index :work_sessions, [:user_id, :window_schedule_repair_id, :checked_out_at]
```

**Option B**: Keep check_ins but add constraint
```ruby
# Add database constraint to prevent overlapping active sessions
add_check_constraint :check_ins, 
  "NOT EXISTS (
    SELECT 1 FROM check_ins ci2 
    WHERE ci2.user_id = check_ins.user_id 
    AND ci2.window_schedule_repair_id = check_ins.window_schedule_repair_id
    AND ci2.action = 0 
    AND ci2.id > check_ins.id
    AND NOT EXISTS (
      SELECT 1 FROM check_ins ci3 
      WHERE ci3.user_id = ci2.user_id 
      AND ci3.window_schedule_repair_id = ci2.window_schedule_repair_id
      AND ci3.action = 1 
      AND ci3.id > ci2.id
    )
  )"
```

**Recommended**: Option A (simpler, clearer intent)

---

### 9. **Geographic Data**

#### Issue
Using `decimal` for lat/lng instead of PostGIS.

#### Recommendation
**If using PostgreSQL**: Enable PostGIS extension

```ruby
enable_extension "postgis"

create_table "buildings" do |t|
  # ... other fields
  t.st_point "coordinates", geographic: true
end

add_index :buildings, :coordinates, using: :gist

# Benefits:
# - Better spatial queries (distance, within radius)
# - More accurate calculations
# - Standard spatial functions
```

**If staying with decimal**: Keep current approach but add helper methods

---

### 10. **Invoice-WRS Relationship Clarity**

#### Issue
- `invoices.window_schedule_repair_id` is optional
- `invoices.freshbooks_client_id` is required (unless `generated_by == 'wrs_form'`)
- Relationship unclear

#### Recommendation
Clarify the relationship:

```ruby
# Option A: Invoice always belongs to WRS
change_column_null :invoices, :window_schedule_repair_id, false

# Option B: Support standalone invoices
# Keep optional but add validation
class Invoice < ApplicationRecord
  validates :window_schedule_repair_id, presence: true, unless: :standalone?
  
  def standalone?
    generated_by == 'manual' && freshbooks_client_id.present?
  end
end
```

**Recommended**: Option A (simpler, clearer business logic)

---

### 11. **Naming Conventions**

#### Issue
- `window_schedule_repairs` is verbose
- Abbreviation `WRS` used throughout codebase

#### Recommendation
**Option A**: Rename to `repair_schedules` or `work_orders`
**Option B**: Keep `window_schedule_repairs` but create alias

```ruby
# If renaming, create migration
rename_table :window_schedule_repairs, :repair_schedules

# Update all foreign keys
rename_column :windows, :window_schedule_repair_id, :repair_schedule_id
# ... etc
```

**Note**: This is a breaking change. Consider keeping current name for backward compatibility.

---

### 12. **Missing Constraints**

#### Recommendations

**A. Add NOT NULL constraints where appropriate**
```ruby
change_column_null :window_schedule_repairs, :name, false
change_column_null :window_schedule_repairs, :building_id, false
change_column_null :window_schedule_repairs, :user_id, false
change_column_null :windows, :location, false
change_column_null :tools, :name, false
```

**B. Add CHECK constraints**
```ruby
# Ensure prices are non-negative
add_check_constraint :tools, "price >= 0"
add_check_constraint :window_schedule_repairs, "total_vat_included_price >= 0"
add_check_constraint :window_schedule_repairs, "total_vat_excluded_price >= 0"

# Ensure check-in/check-out pairs
add_check_constraint :check_ins, "action IN (0, 1)" # if using enum as integer
```

---

## Proposed Improved Schema (Key Tables)

### Core Entities (Simplified)

```ruby
# Users - Keep mostly as-is, add audit fields
create_table "users" do |t|
  # ... existing fields
  t.datetime "deleted_at"
  t.index ["deleted_at"]
end

# Buildings - Add PostGIS, keep soft delete
create_table "buildings" do |t|
  t.string "name", null: false
  t.string "street", null: false
  t.string "city", null: false
  t.string "country", null: false
  t.string "zipcode"
  t.st_point "coordinates", geographic: true
  t.bigint "created_by_id"
  t.bigint "updated_by_id"
  t.datetime "deleted_at"
  t.timestamps
end

# Repair Schedules (renamed from window_schedule_repairs)
create_table "repair_schedules" do |t|
  t.string "name", null: false
  t.string "slug", null: false, unique: true
  t.string "flat_number"
  t.string "reference_number"
  t.text "details"
  
  # Relationships
  t.references "user", null: false
  t.references "building", null: false
  
  # Pricing (remove grand_total)
  t.decimal "subtotal", precision: 10, scale: 2, default: 0
  t.decimal "vat_rate", precision: 5, scale: 4, default: 0.20
  t.decimal "vat_amount", precision: 10, scale: 2, default: 0
  t.decimal "total", precision: 10, scale: 2, default: 0
  
  # Status
  t.integer "status", default: 0 # enum: pending, approved, rejected, completed
  
  # Publishing
  t.boolean "is_draft", default: true
  t.boolean "is_archived", default: false
  t.datetime "last_published"
  
  # Audit
  t.bigint "created_by_id"
  t.bigint "updated_by_id"
  t.datetime "deleted_at"
  
  t.timestamps
  
  # Indexes
  t.index ["building_id", "status", "deleted_at"]
  t.index ["user_id", "status", "created_at"]
  t.index ["slug"]
  t.index ["deleted_at"]
end

# Decisions (extracted)
create_table "repair_schedule_decisions" do |t|
  t.references "repair_schedule", null: false, unique: true
  t.string "decision", null: false # approved, rejected
  t.datetime "decision_at", null: false
  t.string "client_email"
  t.string "client_name"
  t.datetime "terms_accepted_at"
  t.string "terms_version"
  t.jsonb "metadata"
  t.timestamps
end

# Webflow Syncs (extracted)
create_table "webflow_syncs" do |t|
  t.references "syncable", polymorphic: true, null: false
  t.string "webflow_item_id"
  t.string "webflow_collection_id"
  t.string "webflow_main_image_url"
  t.string "webflow_created_on"
  t.string "webflow_published_on"
  t.string "webflow_updated_on"
  t.datetime "last_synced_at"
  t.jsonb "sync_metadata"
  t.timestamps
  
  t.index ["syncable_type", "syncable_id"], unique: true
end

# Windows - Simplified
create_table "windows" do |t|
  t.string "location", null: false
  t.references "repair_schedule", null: false
  t.bigint "created_by_id"
  t.bigint "updated_by_id"
  t.timestamps
end

# Tool Catalog (new)
create_table "tool_catalog" do |t|
  t.string "name", null: false, unique: true
  t.decimal "default_price", precision: 10, scale: 2, null: false
  t.text "description"
  t.boolean "is_active", default: true
  t.integer "display_order", default: 0
  t.timestamps
end

# Tools - Reference catalog, decimal price
create_table "tools" do |t|
  t.references "window", null: false
  t.references "tool_catalog", optional: true
  t.string "name", null: false # Denormalized for history
  t.decimal "price", precision: 10, scale: 2, null: false, default: 0
  t.bigint "created_by_id"
  t.bigint "updated_by_id"
  t.timestamps
  
  t.check_constraint "price >= 0"
end

# Work Sessions (replaces check_ins)
create_table "work_sessions" do |t|
  t.references "user", null: false
  t.references "repair_schedule", null: false
  t.datetime "checked_in_at", null: false
  t.datetime "checked_out_at"
  t.decimal "latitude", precision: 10, scale: 7
  t.decimal "longitude", precision: 10, scale: 7
  t.string "address"
  t.timestamps
  
  t.index ["user_id", "repair_schedule_id", "checked_out_at"]
end

# Notifications - Remove read boolean
create_table "notifications" do |t|
  t.references "user", null: false
  t.references "repair_schedule", optional: true
  t.integer "notification_type", null: false
  t.string "title", null: false
  t.text "message"
  t.datetime "read_at"
  t.jsonb "metadata"
  t.timestamps
  
  t.index ["user_id", "read_at", "created_at"]
  t.index ["repair_schedule_id", "notification_type"]
end

# Price Snapshots (new)
create_table "price_snapshots" do |t|
  t.references "priceable", polymorphic: true, null: false
  t.decimal "subtotal", precision: 10, scale: 2
  t.decimal "vat_rate", precision: 5, scale: 4
  t.decimal "vat_amount", precision: 10, scale: 2
  t.decimal "total", precision: 10, scale: 2
  t.datetime "snapshot_at", null: false
  t.jsonb "line_items"
  t.timestamps
  
  t.index ["priceable_type", "priceable_id", "snapshot_at"]
end
```

---

## Migration Strategy

### Phase 1: Non-Breaking Changes
1. ✅ Add missing indexes
2. ✅ Add NOT NULL constraints where safe
3. ✅ Add CHECK constraints
4. ✅ Change `tools.price` to decimal
5. ✅ Remove redundant `read` boolean from notifications

### Phase 2: Extractions (Backward Compatible)
1. ✅ Create `webflow_syncs` table, migrate data, add concern
2. ✅ Create `repair_schedule_decisions` table, migrate data
3. ✅ Create `tool_catalog` table, populate, add reference

### Phase 3: Breaking Changes (Requires Coordination)
1. ⚠️ Remove `grand_total` from window_schedule_repairs
2. ⚠️ Remove `address` from window_schedule_repairs
3. ⚠️ Rename `window_schedule_repairs` to `repair_schedules` (if desired)
4. ⚠️ Replace `check_ins` with `work_sessions`

### Phase 4: Enhancements
1. ✅ Add audit fields (`created_by_id`, `updated_by_id`)
2. ✅ Add `price_snapshots` table
3. ✅ Enable PostGIS (if using PostgreSQL)

---

## Key Principles Applied

### 1. **Single Responsibility**
- Extracted Webflow sync logic to separate table
- Extracted decision logic to separate table
- Separated price history from current prices

### 2. **DRY (Don't Repeat Yourself)**
- Tool catalog eliminates price duplication
- Status definitions centralize status management
- Audit concern reusable across models

### 3. **Normalization**
- Removed redundant fields (`grand_total`, `read`, `address`)
- Extracted related data to separate tables
- Created lookup tables for catalog data

### 4. **Scalability**
- Added composite indexes for common queries
- Partial indexes for filtered queries
- PostGIS for spatial queries (if needed)

### 5. **Maintainability**
- Clear naming conventions
- Consistent soft delete strategy
- Centralized configuration (VAT rate, status definitions)

### 6. **Data Integrity**
- NOT NULL constraints where appropriate
- CHECK constraints for business rules
- Foreign key constraints
- Unique constraints

---

## Performance Considerations

### Indexing Strategy
- **Composite indexes** for multi-column WHERE clauses
- **Partial indexes** for filtered queries (e.g., active records only)
- **Covering indexes** for common SELECT queries
- **GIST indexes** for spatial data (PostGIS)

### Query Optimization
- Use `includes`/`preload` to avoid N+1 queries
- Consider materialized views for complex aggregations
- Use database-level calculations for price totals (if needed)

### Caching Strategy
- Cache tool catalog (rarely changes)
- Cache status definitions
- Consider Redis for frequently accessed data

---

## Security Considerations

### Audit Trail
- Track `created_by` and `updated_by` for accountability
- Consider adding `deleted_by` for soft deletes
- Log sensitive operations (price changes, status changes)

### Data Protection
- Ensure soft-deleted records are excluded from default queries
- Add row-level security policies if needed (PostgreSQL)
- Encrypt sensitive fields (PII, payment data)

---

## Testing Recommendations

### Database Tests
- Test all constraints (NOT NULL, CHECK, UNIQUE, FOREIGN KEY)
- Test soft delete behavior
- Test price calculations with edge cases
- Test concurrent check-ins

### Migration Tests
- Test rollback scenarios
- Test data migration accuracy
- Test performance impact of new indexes

---

## Conclusion

The current schema is functional but has opportunities for improvement in:
1. **Data consistency** (price types, redundant fields)
2. **Normalization** (extract Webflow, decisions, status)
3. **Maintainability** (audit trail, tool catalog)
4. **Performance** (indexes, query optimization)
5. **Clarity** (naming, relationships)

The recommended changes prioritize:
- **Simplicity**: Remove redundancy, clarify relationships
- **Scalability**: Add indexes, optimize queries
- **Maintainability**: Extract concerns, centralize configuration
- **Reliability**: Add constraints, audit trail

Most improvements can be implemented incrementally without breaking changes, allowing for gradual migration and testing.
