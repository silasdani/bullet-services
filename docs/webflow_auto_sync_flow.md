# Webflow Auto-Sync Flow

## Overview

This document explains the professional implementation of automatic Webflow synchronization that ensures images are included in the sync.

## The Challenge

When creating or updating a Window Schedule Repair (WRS):
1. WRS record is saved to database
2. Windows are created/updated
3. Images are attached to windows via ActiveStorage
4. `after_commit` callback triggers Webflow sync

**Problem**: ActiveStorage attachments happen within the transaction, but the blob processing can complete after the transaction commits. If the sync job runs immediately, it may not include the image URLs.

## Previous Solution (Workaround)

❌ **Hardcoded delay**: Added a 3-second delay to the sync job
- **Pros**: Simple, works most of the time
- **Cons**: Not professional, arbitrary timing, can still fail with large images or slow uploads

## Current Solution (Professional)

✅ **Explicit sync after all operations complete**

### Architecture

```
Controller → WrsCreationService → Transaction Complete → All Images Attached → Trigger Sync
```

### How It Works

1. **Service Layer Control**: `WrsCreationService` manages the entire flow
   ```ruby
   def create
     ActiveRecord::Base.transaction do
       @wrs.skip_auto_sync = true  # Disable automatic callback
       # Create WRS, windows, and attach images
     end
     
     # After transaction is committed and all images are attached
     trigger_webflow_sync  # Explicitly trigger sync
   end
   ```

2. **Skip Auto-Sync Flag**: New attribute `skip_auto_sync` prevents the automatic callback
   ```ruby
   # In WindowScheduleRepair model
   attr_accessor :skip_auto_sync
   
   def should_auto_sync_to_webflow?
     !deleted? && (is_draft? || webflow_item_id.blank?) && 
     !skip_webflow_sync && !skip_auto_sync
   end
   ```

3. **Explicit Trigger**: Service explicitly triggers sync after all operations
   ```ruby
   def trigger_webflow_sync
     return unless @wrs.is_draft? || @wrs.webflow_item_id.blank?
     return if @wrs.deleted?
     
     # At this point, all images are attached and transaction is committed
     AutoSyncToWebflowJob.perform_later(@wrs.id)
   end
   ```

### Benefits

✅ **Deterministic**: Sync happens exactly when we want it to
✅ **No arbitrary delays**: Images are guaranteed to be attached
✅ **Clear flow**: Easy to understand and maintain
✅ **Testable**: Can verify sync happens after image attachment
✅ **Professional**: Production-grade implementation

### Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│ 1. WrsCreationService.create/update                    │
│    - Set skip_auto_sync = true                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Database Transaction                                │
│    - Create/update WRS record                          │
│    - Create/update Windows                             │
│    - Create/update Tools                               │
│    - Attach images to Windows (ActiveStorage)          │
│    - Calculate totals                                  │
│    - Save WRS                                          │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼ Transaction commits
┌─────────────────────────────────────────────────────────┐
│ 3. After Transaction (images are attached)             │
│    - trigger_webflow_sync                              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ 4. AutoSyncToWebflowJob.perform_later                  │
│    - Background job processes sync                     │
│    - All images are available                          │
│    - Image URLs are included in Webflow data           │
└─────────────────────────────────────────────────────────┘
```

## Fallback Behavior

The `after_commit` callback is still in place as a fallback for:
- Direct database operations (console, rake tasks)
- Third-party integrations
- Any operations not using `WrsCreationService`

The callback will NOT trigger when:
- `skip_auto_sync = true` (service layer handles it)
- `skip_webflow_sync = true` (syncing FROM Webflow)
- Record is deleted
- Record is published (not a draft)

## Image Logging

The `WebflowAutoSyncService` logs which windows have images attached:

```ruby
WebflowAutoSync: Window 1 has image attached (kitchen-window.jpg)
WebflowAutoSync: Window 2 has NO image
WebflowAutoSync: Window 3 has image attached (bathroom-window.jpg)
```

This helps verify that images are present during sync.

## Testing

To verify the flow works correctly:

1. Create a WRS with images
2. Check logs for image attachment confirmation
3. Verify Webflow item includes image URLs
4. Confirm no timing-related failures

## Code Locations

- **Model**: `app/models/window_schedule_repair.rb`
  - `skip_auto_sync` attribute
  - `should_auto_sync_to_webflow?` condition
  - `after_commit` callback

- **Service**: `app/services/wrs_creation_service.rb`
  - Sets `skip_auto_sync = true`
  - Manages transaction
  - Calls `trigger_webflow_sync` after completion

- **Job**: `app/jobs/auto_sync_to_webflow_job.rb`
  - Runs in background
  - Processes sync via `WebflowAutoSyncService`

- **Sync Service**: `app/services/webflow_auto_sync_service.rb`
  - Handles actual Webflow API calls
  - Logs image status for debugging

## Migration from Old Approach

If you see a 3-second delay in the code, it's from the old workaround. The new approach:
- Removes the delay
- Adds `skip_auto_sync` flag
- Triggers sync explicitly in service layer

No database migrations needed - this is purely a code change.

