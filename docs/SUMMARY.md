# Clean WRS Architecture Summary

## What We Built

A **clean, focused system** for managing Window Schedule Repairs (WRS) with automatic Webflow CMS integration.

## The Problem We Solved

Your Webflow collection is a **single collection** that handles up to 5 windows per WRS item, but the previous implementation was scattered across multiple services with confusing logic.

## The Clean Solution

### 1. **WebflowCollectionMapperService** - Single Source of Truth
```ruby
# Maps Rails models to Webflow collection fields
WebflowCollectionMapperService.to_webflow(wrs)

# Maps Webflow data back to Rails models
WebflowCollectionMapperService.from_webflow(webflow_data)
```

**What it does:**
- Maps your 5 windows to the correct Webflow fields
- Handles images, locations, tools, and prices
- Bidirectional mapping (Rails ↔ Webflow)

### 2. **WrsCreationService** - Mobile App Integration
```ruby
# Mobile app creates WRS with windows and tools
service = WrsCreationService.new(user, params)
result = service.create

# Automatically:
# - Creates WRS, Windows, Tools
# - Calculates totals
# - Syncs to Webflow
```

**What it does:**
- Single endpoint for mobile app
- Handles nested attributes (windows + tools)
- Automatic total calculations
- Triggers Webflow sync

### 3. **WindowImageUploadService** - Image Management
```ruby
# Mobile app uploads window image
service = WindowImageUploadService.new(window)
result = service.upload_image(image_file)

# Automatically:
# - Generates filename: window-1-image.jpg
# - Syncs to Webflow
```

**What it does:**
- Handles image uploads
- Automatic naming convention
- Triggers Webflow sync

## The Flow (Simple & Clear)

```
Mobile App → API → Service → Models → Webflow
```

### Step 1: Create WRS
```
POST /api/v1/window_schedule_repairs
{
  "name": "Kitchen Repair",
  "windows_attributes": [
    {
      "location": "Kitchen",
      "tools_attributes": [
        {"name": "Glass", "price": 100}
      ]
    }
  ]
}
```

### Step 2: Upload Images
```
POST /api/v1/images/upload_window_image
window_id: 123
image: [file]
```

### Step 3: Automatic Webflow Sync
- Background job syncs to Webflow
- Maps to your collection structure
- Updates all 5 window fields

## Key Benefits

✅ **Single Responsibility**: Each service does one thing well  
✅ **Clean API**: Simple endpoints for mobile app  
✅ **Automatic Sync**: Webflow updates happen in background  
✅ **Consistent Naming**: Images follow `window-{number}-image` pattern  
✅ **Transaction Safe**: All operations wrapped in database transactions  
✅ **Error Handling**: Comprehensive error handling and logging  

## Files Created/Modified

### New Services
- `app/services/webflow_collection_mapper_service.rb` - Maps Rails ↔ Webflow
- `app/services/wrs_creation_service.rb` - Handles WRS creation/updates
- `app/services/window_image_upload_service.rb` - Handles image uploads

### Updated Controllers
- `app/controllers/api/v1/window_schedule_repairs_controller.rb` - Uses new service
- `app/controllers/api/v1/images_controller.rb` - Simplified image handling

### Enhanced Models
- `app/models/window.rb` - Added helper methods for tools and images

### Background Jobs
- `app/jobs/webflow_upload_job.rb` - Handles Webflow sync

## Usage Examples

### Mobile App - Create WRS
```javascript
const createWRS = async (wrsData) => {
  const response = await fetch('/api/v1/window_schedule_repairs', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(wrsData)
  });
  return response.json();
};
```

### Mobile App - Upload Image
```javascript
const uploadImage = async (windowId, imageUri) => {
  const formData = new FormData();
  formData.append('window_id', windowId);
  formData.append('image', {
    uri: imageUri,
    type: 'image/jpeg',
    name: 'window_image.jpg'
  });

  const response = await fetch('/api/v1/images/upload_window_image', {
    method: 'POST',
    body: formData
  });
  return response.json();
};
```

## Configuration

### Required
- AWS S3 credentials in `rails credentials:edit`
- Webflow collection ID in WRS records

### Automatic
- Image naming: `window-1-image.jpg`, `window-2-image.jpg`, etc.
- Total calculations with VAT
- Webflow sync after any changes

## Testing

```bash
# Test WRS creation
rails test test/services/wrs_creation_service_test.rb

# Test S3 connection
rails s3:test_connection

# Test image upload
rails s3:upload_test_image
```

## What This Solves

1. **Clean Architecture**: No more scattered logic
2. **Mobile Friendly**: Simple API endpoints
3. **Automatic Sync**: Webflow updates happen seamlessly
4. **Professional Code**: Following Rails best practices
5. **Easy Maintenance**: Each service has a clear purpose

The system now works exactly like your Webflow collection structure - **one WRS item contains up to 5 windows with their images, locations, tools, and prices**.
