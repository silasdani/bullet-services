# Image Upload System Setup

## Overview

The image upload system has been set up to handle images for windows and window schedule repairs, with automatic S3 storage.

## Components Implemented

### 1. Images Controller (`app/controllers/api/v1/images_controller.rb`)
- **`upload_window_image`**: Uploads a single image to a specific window
- **`upload_multiple_images`**: Uploads multiple images to a WRS
- Automatic image naming: `window-{number}-image`

### 2. Image Policy (`app/policies/image_policy.rb`)
- Authorization rules for image uploads
- Role-based access control (admin, employee, client)

### 5. Enhanced Window Model (`app/models/window.rb`)
- Added `image_name` method for automatic naming
- Added `image_url` method for direct URL access

### 6. Updated Window Serializer (`app/serializers/window_serializer.rb`)
- Includes image name and URL in API responses
- Enhanced image metadata

## API Endpoints

### Upload Window Image
```
POST /api/v1/images/upload_window_image
Content-Type: multipart/form-data

Parameters:
- window_id: ID of the window
- image: Image file

Response:
{
  "success": true,
  "message": "Image uploaded successfully",
  "image_url": "https://s3.amazonaws.com/bucket/image.jpg",
  "image_name": "window-1-image"
}
```

### Upload Multiple Images to WRS
```
POST /api/v1/images/upload_multiple_images
Content-Type: multipart/form-data

Parameters:
- window_schedule_repair_id: ID of the WRS
- images[]: Array of image files

Response:
{
  "success": true,
  "message": "Images uploaded successfully",
  "image_count": 2,
  "image_urls": ["url1", "url2"]
}
```

## Configuration

### S3 Storage
- **Bucket**: `bullet-services`
- **Region**: `eu-north-1`
- **Service**: `:amazon` (configured in development.rb)

### AWS Credentials
Configure in `rails credentials:edit`:
```yaml
aws:
  access_key_id: your_access_key
  secret_access_key: your_secret_key
```

### Active Storage
- **Service**: S3 (production), Local (development)
- **Proxy Routes**: Enabled for secure access
- **File Naming**: Automatic based on window position

## Image Naming Convention

Window images are automatically named using the pattern:
```
window-{number}-image.{extension}
```

Where `{number}` represents the order of the window within the WRS (1-based indexing).

## Testing

### Rake Tasks
```bash
# Test S3 connection
rails s3:test_connection

# Upload test image to S3
rails s3:upload_test_image
```

### Test Files
- `test/controllers/api/v1/images_controller_test.rb`
- Test fixtures in `test/fixtures/files/`

### Postman Collection
- `postman/Image_Upload_Collection.json`
- Ready-to-use API testing collection

## Usage Examples

### React Native Integration
```javascript
import * as ImagePicker from 'react-native-image-picker';

const uploadWindowImage = async (windowId, imageUri) => {
  const formData = new FormData();
  formData.append('window_id', windowId);
  formData.append('image', {
    uri: imageUri,
    type: 'image/jpeg',
    name: 'window_image.jpg'
  });

  const response = await fetch('/api/v1/images/upload_window_image', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'multipart/form-data'
    },
    body: formData
  });

  return response.json();
};
```

### Camera Integration
```javascript
const takePhoto = async () => {
  const result = await ImagePicker.launchCamera({
    mediaType: 'photo',
    quality: 0.8
  });

  if (!result.didCancel && result.assets[0]) {
    await uploadWindowImage(windowId, result.assets[0].uri);
  }
};
```

## Security Features

- **Authorization**: Role-based access control
- **File Validation**: Active Storage handles file types
- **Secure URLs**: Rails storage proxy for controlled access

## Error Handling

- Comprehensive error logging
- Graceful fallbacks for failed uploads
- User-friendly error messages
- Automatic retry for failures

## Performance Considerations

- Efficient S3 uploads
- Image compression via Active Storage
- Background job processing

## Monitoring

- Rails logging for all operations
- S3 upload tracking
- Background job status tracking
