# Webflow Auto-Sync Documentation

## Overview

The Webflow Auto-Sync feature provides automatic end-to-end synchronization between the Bullet Services app and Webflow. When Window Schedule Repair (WRS) records are created or updated in the app, they are automatically synchronized to Webflow as **draft items**.

## Key Features

### 1. Automatic Synchronization
- **Trigger**: Automatically syncs when a WRS is created or updated
- **Execution**: Runs asynchronously in the background (non-blocking)
- **Protection**: Only syncs draft items to prevent overwriting published content

### 2. Draft Protection
The auto-sync system implements strict rules to protect published content:

- ✅ **Auto-syncs** if the record is marked as draft (`is_draft = true`)
- ✅ **Auto-syncs** if the record has never been synced to Webflow (`webflow_item_id` is blank)
- ❌ **Does NOT auto-sync** if the record is published (`is_draft = false` and `webflow_item_id` is present)

### 3. Background Processing
- Syncs are performed asynchronously using `AutoSyncToWebflowJob`
- Retries automatically on failure (up to 3 times for API errors)
- Does not block the main request/response cycle

## Architecture

### Components

1. **WindowScheduleRepair Model** (`app/models/window_schedule_repair.rb`)
   - Contains `after_commit` callback that triggers auto-sync
   - Implements `should_auto_sync_to_webflow?` guard method

2. **WebflowAutoSyncService** (`app/services/webflow_auto_sync_service.rb`)
   - Handles the sync logic
   - Creates new Webflow items as drafts
   - Updates existing draft items
   - Prevents updates to published items

3. **AutoSyncToWebflowJob** (`app/jobs/auto_sync_to_webflow_job.rb`)
   - Background job for asynchronous processing
   - Handles retries on failure
   - Logs sync results

## Workflow

### Creating a New WRS

```
1. User creates WRS in app
   ↓
2. WRS saved to database (is_draft = true by default)
   ↓
3. after_commit callback fires
   ↓
4. AutoSyncToWebflowJob queued
   ↓
5. WebflowAutoSyncService creates draft item in Webflow
   ↓
6. webflow_item_id saved to WRS record
```

### Updating an Existing Draft WRS

```
1. User updates draft WRS in app
   ↓
2. WRS saved to database
   ↓
3. after_commit callback fires (is_draft = true)
   ↓
4. AutoSyncToWebflowJob queued
   ↓
5. WebflowAutoSyncService updates draft item in Webflow
```

### Updating a Published WRS

```
1. User updates published WRS in app
   ↓
2. WRS saved to database
   ↓
3. after_commit callback fires
   ↓
4. should_auto_sync_to_webflow? returns false (is_draft = false)
   ↓
5. Auto-sync SKIPPED (protected)
   
   To sync: User must manually publish via API endpoint
```

## API Behavior

### Create WRS
```bash
POST /api/v1/window_schedule_repairs
```
- Creates WRS in database as draft
- **Automatically syncs to Webflow as draft**
- Returns immediately (sync happens in background)

### Update Draft WRS
```bash
PATCH /api/v1/window_schedule_repairs/:id
```
- Updates WRS in database
- **Automatically syncs to Webflow if still draft**
- Returns immediately (sync happens in background)

### Update Published WRS
```bash
PATCH /api/v1/window_schedule_repairs/:id
```
- Updates WRS in database
- **Does NOT auto-sync** (protection enabled)
- Must manually republish using publish endpoint

### Manual Publish
```bash
POST /api/v1/window_schedule_repairs/:id/publish_to_webflow
```
- Updates item in Webflow with latest data
- Publishes the item to Webflow site
- Marks local record as published (`is_draft = false`)

### Manual Unpublish
```bash
POST /api/v1/window_schedule_repairs/:id/unpublish_from_webflow
```
- Unpublishes item from Webflow site
- Marks local record as draft (`is_draft = true`)
- Future updates will auto-sync again

## Configuration

### Environment Variables
The following environment variables must be set:

```bash
WEBFLOW_TOKEN=your_webflow_api_token
WEBFLOW_SITE_ID=your_webflow_site_id
WEBFLOW_WRS_COLLECTION_ID=your_collection_id
```

### Job Queue
The background job uses the `:default` queue. Make sure your job processor is running:

```bash
# Development
bin/jobs

# Production (with Kamal)
# Jobs are processed automatically via solid_queue
```

## Safety Features

### 1. Validation Before Sync
Auto-sync only proceeds if:
- Record is not deleted
- Required fields are present (name, address, slug)
- Record is draft OR has never been synced

### 2. Error Handling
- API errors are caught and logged
- Jobs retry automatically on failure
- Main request is never blocked by sync errors

### 3. Logging
All sync operations are logged:
```
✅ Success: "WebflowAutoSync: Created WRS #123 in Webflow as draft"
⚠️  Skipped: "WebflowAutoSync: Skipping WRS #123 - item is published"
❌ Error: "WebflowAutoSync failed for WRS #123: [error message]"
```

## Best Practices

### For Development
1. Always test with draft items first
2. Monitor logs for sync status
3. Ensure job queue is running

### For Production
1. Published items are protected from accidental overwrites
2. Use manual publish endpoint for published items
3. Monitor job queue for failures
4. Review logs regularly

### Workflow Recommendations

1. **Create → Auto-sync → Review in Webflow → Publish**
   - Create WRS in app (auto-syncs as draft)
   - Review in Webflow CMS
   - Manually publish when ready

2. **Edit Draft → Auto-sync → Publish**
   - Edit draft WRS in app (auto-syncs changes)
   - Changes appear immediately in Webflow draft
   - Publish when ready

3. **Edit Published → Manual Publish**
   - Edit published WRS in app
   - Review changes locally
   - Manually republish using publish endpoint

## Troubleshooting

### Issue: Items not syncing
**Check:**
1. Is the job queue running? (`bin/jobs` in dev)
2. Are environment variables set correctly?
3. Check logs for errors: `tail -f log/development.log`
4. Is the item marked as draft?

### Issue: Published items getting updated
**This should NOT happen.** If it does:
1. Check `is_draft` value in database
2. Review logs for auto-sync activity
3. Verify `should_auto_sync_to_webflow?` logic

### Issue: Sync failures
**Check:**
1. Webflow API token validity
2. Rate limiting (60 requests/minute)
3. Required fields are present
4. Webflow collection schema matches data

## Testing

### Manual Testing

```ruby
# In Rails console

# Create a WRS (should auto-sync)
wrs = WindowScheduleRepair.create!(
  name: "Test WRS",
  address: "123 Test St",
  flat_number: "Apt 1",
  user: User.first
)

# Check if job was queued
# Check logs for: "AutoSyncToWebflowJob: Successfully synced WRS #..."

# Update draft WRS (should auto-sync)
wrs.update!(name: "Updated Test WRS")
# Check logs again

# Publish WRS
wrs.mark_as_published!

# Update published WRS (should NOT auto-sync)
wrs.update!(name: "Another Update")
# Logs should show: "Skipped WRS #... - item is published"
```

### Disable Auto-Sync Temporarily

If you need to disable auto-sync temporarily:

```ruby
# In Rails console
WindowScheduleRepair.skip_callback(:commit, :after, :auto_sync_to_webflow)

# Re-enable
WindowScheduleRepair.set_callback(:commit, :after, :auto_sync_to_webflow)
```

## Migration from Manual Sync

If you have existing WRS records that were created before auto-sync:

1. They will have `is_draft = nil` in the database
2. The `set_default_webflow_flags` callback only applies to new records
3. To enable auto-sync for existing records, set their `is_draft` flag:

```ruby
# Mark all unsynced records as drafts
WindowScheduleRepair.where(webflow_item_id: nil).update_all(is_draft: true)

# Mark synced but unpublished records as drafts
WindowScheduleRepair.where.not(webflow_item_id: nil)
                     .where(is_draft: nil)
                     .update_all(is_draft: true)
```

## Summary

The Webflow Auto-Sync feature provides:
- ✅ Automatic synchronization of draft items
- ✅ Protection for published content
- ✅ Non-blocking asynchronous processing
- ✅ Automatic retries on failure
- ✅ Comprehensive logging
- ✅ Simple workflow for developers and users

This ensures that your app and Webflow stay in sync while maintaining the integrity of published content.

