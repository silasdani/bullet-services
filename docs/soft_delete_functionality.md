# Soft Delete Functionality for Window Schedule Repairs (WRS)

## Overview

This document describes the soft delete functionality implemented for Window Schedule Repairs (WRS) to prevent accidental data loss in production.

## Features

### 1. Soft Delete Implementation
- WRS records are no longer permanently deleted when the `DELETE` endpoint is called
- Instead, they are marked as deleted by setting the `deleted_at` timestamp
- Records with `deleted_at` set are excluded from normal queries by default

### 2. Database Changes
- Added `deleted_at` datetime column to `window_schedule_repairs` table
- Added index on `deleted_at` for better query performance

### 3. Model Changes
- Added `default_scope` to only show active records by default
- Added scopes: `active`, `deleted`, `with_deleted`
- Added methods: `soft_delete!`, `restore!`, `deleted?`, `active?`

### 4. API Changes

#### Delete Endpoint
- `DELETE /api/v1/wrs/:id` now performs soft delete
- Returns success message with `deleted_at` timestamp

#### New Restore Endpoint
- `POST /api/v1/wrs/:id/restore` restores a soft-deleted WRS
- Returns the restored WRS data

### 5. Serializer Updates
- Added `deleted_at`, `deleted`, and `active` attributes to the response
- Clients can now see the deletion status of WRS records

## Usage Examples

### Soft Delete a WRS
```bash
DELETE /api/v1/wrs/123
```

Response:
```json
{
  "success": true,
  "message": "WRS deleted successfully",
  "deleted_at": "2025-09-18T18:44:03.000Z"
}
```

### Restore a WRS
```bash
POST /api/v1/wrs/123/restore
```

Response:
```json
{
  "success": true,
  "message": "WRS restored successfully",
  "data": {
    "id": 123,
    "name": "Window Repair",
    "deleted": false,
    "active": true,
    "deleted_at": null,
    // ... other WRS attributes
  }
}
```

### Query Deleted Records
```ruby
# In Rails console or service
deleted_wrs = WindowScheduleRepair.deleted
all_wrs = WindowScheduleRepair.with_deleted
```

## Security

- Only admins and the WRS owner can delete/restore records
- Same authorization rules apply as before
- Deleted records are not visible in normal API responses

## Migration

The migration has been run and is ready for production. No data loss will occur as existing records will have `deleted_at` set to `NULL` (active).

## Benefits

1. **Data Safety**: Prevents accidental permanent deletion
2. **Audit Trail**: Maintains record of when items were deleted
3. **Recovery**: Easy restoration of accidentally deleted records
4. **Performance**: Minimal impact on existing queries
5. **Backward Compatibility**: Existing API behavior is preserved for active records
