# Webflow Auto-Sync - Quick Reference

## 🎯 What Was Implemented

**Automatic end-to-end synchronization to Webflow with protection for published items.**

## 🔑 Key Behavior

| Scenario | WRS State | Auto-Sync? |
|----------|-----------|------------|
| Create new WRS | `is_draft = true` (default) | ✅ YES - Creates draft in Webflow |
| Update draft WRS | `is_draft = true` | ✅ YES - Updates draft in Webflow |
| Update published WRS | `is_draft = false` + has `webflow_item_id` | ❌ NO - Protected from auto-sync |
| Update never-synced WRS | No `webflow_item_id` | ✅ YES - Syncs regardless of draft status |
| Update deleted WRS | `deleted_at` is set | ❌ NO - Deleted items don't sync |

## 📁 Files Created

```
app/
  services/
    webflow_auto_sync_service.rb       ← Core sync logic
  jobs/
    auto_sync_to_webflow_job.rb        ← Background job
  
docs/
  webflow_auto_sync.md                 ← Full documentation

test/
  services/
    webflow_auto_sync_service_test.rb  ← Service tests
  models/
    window_schedule_repair_auto_sync_test.rb  ← Model tests

db/
  migrate/
    20251008122018_change_is_draft_default_to_true.rb  ← Migration
```

## 🔧 Files Modified

```
app/
  models/
    window_schedule_repair.rb          ← Added auto-sync callbacks
    concerns/
      wrs.rb                           ← Respects draft status
  services/
    wrs_creation_service.rb            ← Removed manual sync calls
```

## 🚀 How to Use

### 1. Run Migration (if not already done)
```bash
bin/rails db:migrate
```

### 2. Ensure Job Queue is Running
```bash
# Development
bin/jobs

# Production - already running via solid_queue
```

### 3. Create WRS (Auto-syncs)
```bash
POST /api/v1/window_schedule_repairs
{
  "window_schedule_repair": {
    "name": "Test WRS",
    "address": "123 Main St",
    "flat_number": "Apt 1"
  }
}
```
→ Creates in DB as draft → Auto-syncs to Webflow

### 4. Update Draft WRS (Auto-syncs)
```bash
PATCH /api/v1/window_schedule_repairs/:id
{
  "window_schedule_repair": {
    "name": "Updated Name"
  }
}
```
→ Updates in DB → Auto-syncs to Webflow

### 5. Publish WRS
```bash
POST /api/v1/window_schedule_repairs/:id/publish_to_webflow
```
→ Publishes to Webflow → Sets `is_draft = false`

### 6. Update Published WRS (PROTECTED - No Auto-sync)
```bash
PATCH /api/v1/window_schedule_repairs/:id
{
  "window_schedule_repair": {
    "name": "Another Update"
  }
}
```
→ Updates in DB → **Does NOT auto-sync** (protected)
→ Must manually republish to sync changes

## 📊 Monitoring

### Check Logs
```bash
tail -f log/development.log | grep "WebflowAutoSync"
```

### Success Messages
```
✅ WebflowAutoSync: Created WRS #123 in Webflow as draft (webflow-abc123)
✅ WebflowAutoSync: Updated WRS #123 in Webflow (webflow-abc123)
```

### Protection Messages
```
⚠️  WebflowAutoSync: Skipping WRS #123 - item is published
⚠️  WebflowAutoSync: Skipping WRS #123 - record_deleted
```

### Error Messages
```
❌ WebflowAutoSync failed for WRS #123: [error message]
```

## 🔒 Safety Features

1. **Draft Protection** - Published items never auto-sync
2. **Async Processing** - Never blocks requests
3. **Automatic Retries** - Up to 3 attempts on API errors
4. **Validation** - Checks required fields before sync
5. **Comprehensive Logging** - Track all sync operations

## 🧪 Test in Console

```ruby
# Create draft WRS (auto-syncs)
wrs = WindowScheduleRepair.create!(
  name: "Test",
  address: "123 Test St",
  flat_number: "Apt 1",
  user: User.first
)

# Verify it's draft
wrs.is_draft  # => true

# Update draft (auto-syncs)
wrs.update!(name: "Updated")

# Publish
wrs.mark_as_published!
wrs.is_draft  # => false

# Update published (does NOT auto-sync)
wrs.update!(name: "Another Update")

# Check if it should auto-sync
wrs.send(:should_auto_sync_to_webflow?)  # => false (protected!)
```

## ⚙️ Configuration

Required environment variables:
```bash
WEBFLOW_TOKEN=your_token
WEBFLOW_SITE_ID=your_site_id
WEBFLOW_WRS_COLLECTION_ID=your_collection_id
```

## 🛑 Emergency: Disable Auto-Sync

If you need to temporarily disable auto-sync:

```ruby
# In Rails console
WindowScheduleRepair.skip_callback(:commit, :after, :auto_sync_to_webflow)

# Re-enable
WindowScheduleRepair.set_callback(:commit, :after, :auto_sync_to_webflow)
```

Or comment out in `app/models/window_schedule_repair.rb`:
```ruby
# after_commit :auto_sync_to_webflow, on: [:create, :update], if: :should_auto_sync_to_webflow?
```

## 📚 Full Documentation

See `docs/webflow_auto_sync.md` for complete documentation including:
- Architecture details
- Workflow diagrams
- Troubleshooting guide
- Migration guide
- API reference

## ✅ Implementation Status

All tasks completed:
- ✅ Automatic sync on create/update
- ✅ Protection for published items
- ✅ Background job processing
- ✅ Error handling and retries
- ✅ Comprehensive logging
- ✅ Database migration
- ✅ Tests
- ✅ Documentation

**The system is ready for use!**

