# WRS Creation and Image Upload Flow

## Overview
This document explains the clean, focused flow for creating Window Schedule Repairs (WRS) and uploading images from the mobile app.

## Architecture

```
Mobile App → API → Service Layer → Models → Webflow
```

## 1. WRS Creation Flow

### Mobile App Request
```json
POST /api/v1/window_schedule_repairs
{
  "name": "Kitchen Window Repair",
  "address": "123 Main St",
  "flat_number": "Apt 4B",
  "windows_attributes": [
    {
      "location": "Kitchen",
      "tools_attributes": [
        { "name": "Glass Panel", "price": 150.00 },
        { "name": "Installation", "price": 75.00 }
      ]
    },
    {
      "location": "Living Room",
      "tools_attributes": [
        { "name": "Frame Repair", "price": 200.00 }
      ]
    }
  ]
}
```

### Backend Processing
1. **WrsCreationService** receives the request
2. Creates WRS record
3. Creates Windows with their Tools
4. Calculates totals automatically
5. Triggers Webflow sync (if collection ID provided)

### Response
```json
{
  "success": true,
  "message": "WRS created successfully",
  "id": 123,
  "name": "Kitchen Window Repair",
  "address": "123 Main St"
}
```

## 2. Image Upload Flow

### Mobile App Request
```json
POST /api/v1/images/upload_window_image
Content-Type: multipart/form-data

window_id: 456
image: [binary file]
```

### Backend Processing
1. **WindowImageUploadService** receives the image
2. Removes existing image (if any)
3. Attaches new image
4. Generates filename: `window-1-image.jpg`
5. Triggers Webflow sync

### Response
```json
{
  "success": true,
  "image_url": "https://s3.amazonaws.com/bucket/window-1-image.jpg",
  "image_name": "window-1-image.jpg",
  "message": "Image uploaded successfully"
}
```

## 3. Webflow Sync Flow

### Automatic Sync
- **When**: After WRS creation/update or image upload
- **How**: Background job (`WebflowUploadJob`)
- **What**: Maps Rails models to Webflow collection fields

### Webflow Collection Mapping
```json
{
  "fieldData": {
    "name": "Kitchen Window Repair",
    "project-summary": "123 Main St",
    "flat-number": "Apt 4B",
    
    "main-project-image": "https://s3.amazonaws.com/bucket/window-1-image.jpg",
    "window-location": "Kitchen",
    "window-1-items-2": "Glass Panel, Installation",
    "window-1-items-prices-3": "150.0, 75.0",
    
    "window-2": "https://s3.amazonaws.com/bucket/window-2-image.jpg",
    "window-2-location": "Living Room",
    "window-2-items-2": "Frame Repair",
    "window-2-items-prices-3": "200.0",
    
    "total-incl-vat": 510.0,
    "total-exc-vat": 425.0,
    "grand-total": 510.0
  }
}
```

## 4. Service Layer

### WrsCreationService
- **Purpose**: Handle WRS creation/updates
- **Responsibility**: Create WRS, Windows, Tools, calculate totals
- **Webflow**: Trigger sync after successful save

### WindowImageUploadService
- **Purpose**: Handle window image uploads
- **Responsibility**: Upload image, generate filename, trigger Webflow sync
- **Naming**: Automatic `window-{number}-image` format

### WebflowCollectionMapperService
- **Purpose**: Map between Rails models and Webflow collection
- **Responsibility**: Convert data structures bidirectionally
- **Fields**: Handle all 5 windows with their images, locations, tools, and prices

## 5. Data Flow Summary

```
1. Mobile App creates WRS with windows and tools
2. WrsCreationService processes and saves to database
3. WebflowUploadJob syncs to Webflow CMS
4. Mobile App uploads images for specific windows
5. WindowImageUploadService processes images
6. WebflowUploadJob syncs updated data to Webflow
7. Webflow displays complete WRS with images
```

## 6. Key Benefits

- **Clean Separation**: Each service has a single responsibility
- **Automatic Sync**: Webflow updates happen in background
- **Consistent Naming**: Images follow `window-{number}-image` pattern
- **Transaction Safety**: All operations wrapped in database transactions
- **Error Handling**: Comprehensive error handling and logging
- **Mobile Friendly**: Simple API endpoints for mobile app integration

## 7. Configuration

### Required Fields
- `webflow_collection_id`: To enable Webflow sync
- `webflow_item_id`: Automatically set after first sync

### S3 Storage
- Images stored in `bullet-services` bucket
- Public access for Webflow integration
- Automatic filename generation

### Background Jobs
- Uses Rails Active Job for Webflow sync
- Prevents blocking mobile app responses
- Automatic retry on failure
