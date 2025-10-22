# Services Architecture

This document outlines the refactored services architecture for the Bullet Services application.

## Overview

The services have been refactored into a modular, professional structure with clear separation of concerns, proper inheritance hierarchies, and backward compatibility.

## Architecture

### Base Classes

#### `ApplicationService`
- Base class for all services
- Provides common functionality: error handling, logging, validation
- Includes `ActiveModel::Model` and `ActiveModel::Attributes` for consistent interface
- Methods: `call`, `success?`, `failure?`, `add_error`, `log_*`

### Namespaces

#### `Webflow` Namespace
All Webflow-related services are organized under the `Webflow` module:

- **`Webflow::BaseService`** - Base class for Webflow services
  - Handles HTTP requests, rate limiting, error handling
  - Manages API credentials and configuration

- **`Webflow::CollectionService`** - Collection management
  - `list_collections`
  - `get_collection`

- **`Webflow::ItemService`** - Item CRUD operations
  - `list_items`, `get_item`, `create_item`, `update_item`, `delete_item`
  - `publish_items`, `unpublish_items`

- **`Webflow::ItemBuilderService`** - Data transformation
  - Builds Webflow-formatted item data from field data

- **`Webflow::ImageMirrorService`** - Image handling
  - Downloads and mirrors images from Webflow URLs
  - Handles ActiveStorage attachment

- **`Webflow::AutoSyncService`** - Automatic synchronization
  - Syncs WRS records to Webflow as drafts
  - Handles validation and error cases

#### `Wrs` Namespace
All Window Schedule Repair services are organized under the `Wrs` module:

- **`Wrs::BaseService`** - Base class for WRS services
  - Provides common WRS operations
  - Handles auto-sync flags and Webflow job triggering

- **`Wrs::CreationService`** - WRS creation and updates
  - `call` - Creates new WRS with windows and tools
  - `update(wrs_id)` - Updates existing WRS
  - Handles image attachments and validation

- **`Wrs::SyncService`** - Webflow synchronization
  - `sync_single(wrs_data)` - Syncs single WRS from Webflow
  - `sync_batch(wrs_items)` - Bulk sync operation
  - Handles complex data transformation and bulk operations

## Usage Examples

### Using New Modular Services

```ruby
# Create a new WRS
service = Wrs::CreationService.new(user: user, params: params)
result = service.call
if result[:success]
  wrs = result[:wrs]
else
  errors = service.errors
end

# Sync from Webflow
sync_service = Wrs::SyncService.new(admin_user: admin_user)
result = sync_service.sync_single(webflow_data)

# Auto-sync to Webflow
auto_sync = Webflow::AutoSyncService.new(wrs: wrs)
result = auto_sync.call
```

### Backward Compatibility

The old service names still work through facade classes:

```ruby
# These still work exactly as before
WebflowService.new
WebflowAutoSyncService.new(wrs)
WrsCreationService.new(user, params)
WrsSyncService.new(admin_user)
```

## Benefits

1. **Modularity**: Each service has a single responsibility
2. **Testability**: Smaller, focused classes are easier to test
3. **Maintainability**: Clear structure makes code easier to understand and modify
4. **Reusability**: Common functionality is extracted to base classes
5. **Backward Compatibility**: Existing code continues to work without changes
6. **Professional Structure**: Follows Rails conventions and best practices

## Migration Guide

### For New Code
Use the new modular services directly:

```ruby
# Instead of WebflowService.new
collection_service = Webflow::CollectionService.new
item_service = Webflow::ItemService.new

# Instead of WrsCreationService.new
creation_service = Wrs::CreationService.new(user: user, params: params)
```

### For Existing Code
No changes required - facade classes maintain backward compatibility.

### For Tests
Update tests to use the new service structure for better isolation and testing.

## File Structure

```
app/services/
├── application_service.rb           # Base service class
├── service_facades.rb              # Backward compatibility facades
├── webflow/
│   ├── base_service.rb             # Webflow base class
│   ├── collection_service.rb       # Collection operations
│   ├── item_service.rb             # Item CRUD operations
│   ├── item_builder_service.rb     # Data transformation
│   ├── image_mirror_service.rb     # Image handling
│   └── auto_sync_service.rb        # Auto-sync logic
└── wrs/
    ├── base_service.rb             # WRS base class
    ├── creation_service.rb         # WRS creation/updates
    └── sync_service.rb             # Webflow synchronization
```

## Error Handling

All services follow a consistent error handling pattern:

- Use `with_error_handling` for exception handling
- Return structured results with `success`/`failure` status
- Log errors appropriately using the base class logging methods
- Maintain error state in the `errors` array

## Future Enhancements

1. Add service-specific validators
2. Implement service-level caching
3. Add service monitoring and metrics
4. Create service-specific configuration classes
5. Add service documentation generation
