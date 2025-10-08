# Webflow REST API Integration

This document describes the comprehensive Webflow REST API integration implemented in the Rails application.

## Overview

The integration provides full access to Webflow's REST API v2, including:
- Sites management
- Collections and items
- Forms and submissions
- Assets management
- User accounts
- Comments

## Authentication

The integration uses the `WEBFLOW_TOKEN` from Rails credentials for authentication. This token should have the following permissions:
- Edit and read access
- User Accounts
- Assets
- CMS
- Comments
- Forms
- Read-only access
- Authorized user

## Configuration

Add the following to your Rails credentials:

```bash
rails credentials:edit
```

```yaml
WEBFLOW_TOKEN: "your_webflow_api_token_here"
WEBFLOW_SITE_ID: "your_site_id_here"
WEBFLOW_COLLECTION_ID: "your_collection_id_here"
```

## Service Class

The `WebflowService` class provides a comprehensive interface to the Webflow API:

### Features
- Rate limiting (60 requests per minute)
- Error handling with custom `WebflowApiError` class
- Automatic request logging
- Support for all Webflow API endpoints

### Usage Examples

```ruby
# Initialize the service
webflow = WebflowService.new

# List all sites
sites = webflow.list_sites

# Get a specific site
site = webflow.get_site("site_id")

# List collections for a site
collections = webflow.list_collections("site_id")

# Create a new collection
collection_data = {
  name: "My Collection",
  slug: "my-collection",
  singularName: "Item",
  pluralName: "Items"
}
collection = webflow.create_collection("site_id", collection_data)

# List items in a collection
items = webflow.list_items("site_id", "collection_id")

# Create a new item
item_data = {
  fieldData: {
    name: "Item Name",
    description: "Item description"
  },
  isArchived: false,
  isDraft: false
}
item = webflow.create_item("site_id", "collection_id", item_data)

# Publish items (sets isDraft to false)
# Note: In Webflow v2, publishing is done by updating the isDraft field
webflow.publish_items(["item_id_1", "item_id_2"])

# Manage forms
forms = webflow.list_forms("site_id")
submission = webflow.create_form_submission("site_id", "form_id", { data: { name: "John" } })

# Manage assets
assets = webflow.list_assets("site_id")
asset = webflow.create_asset("site_id", { name: "Image", url: "https://example.com/image.jpg" })

# Manage users
users = webflow.list_users("site_id")
user = webflow.create_user("site_id", { email: "user@example.com", firstName: "John" })

# Manage comments
comments = webflow.list_comments("site_id")
comment = webflow.create_comment("site_id", { content: "Great post!", author: "John" })
```

## API Endpoints

The integration provides REST API endpoints for all Webflow operations:

### Sites
- `GET /api/v1/webflow/sites` - List all sites
- `GET /api/v1/webflow/sites/:site_id` - Get specific site

### Collections
- `GET /api/v1/webflow/sites/:site_id/collections` - List collections
- `GET /api/v1/webflow/sites/:site_id/collections/:collection_id` - Get collection
- `POST /api/v1/webflow/sites/:site_id/collections` - Create collection
- `PATCH /api/v1/webflow/sites/:site_id/collections/:collection_id` - Update collection
- `DELETE /api/v1/webflow/sites/:site_id/collections/:collection_id` - Delete collection

### Collection Items
- `GET /api/v1/webflow/sites/:site_id/collections/:collection_id/items` - List items
- `GET /api/v1/webflow/sites/:site_id/collections/:collection_id/items/:item_id` - Get item
- `POST /api/v1/webflow/sites/:site_id/collections/:collection_id/items` - Create item
- `PATCH /api/v1/webflow/sites/:site_id/collections/:collection_id/items/:item_id` - Update item
- `DELETE /api/v1/webflow/sites/:site_id/collections/:collection_id/items/:item_id` - Delete item
- `POST /api/v1/webflow/sites/:site_id/collections/:collection_id/items/publish` - Publish items (sets isDraft to false via PATCH)
- `POST /api/v1/webflow/sites/:site_id/collections/:collection_id/items/unpublish` - Unpublish items (sets isDraft to true via PATCH)

### Forms
- `GET /api/v1/webflow/sites/:site_id/forms` - List forms
- `GET /api/v1/webflow/sites/:site_id/forms/:form_id` - Get form
- `POST /api/v1/webflow/sites/:site_id/forms/:form_id/submissions` - Create form submission

### Assets
- `GET /api/v1/webflow/sites/:site_id/assets` - List assets
- `GET /api/v1/webflow/sites/:site_id/assets/:asset_id` - Get asset
- `POST /api/v1/webflow/sites/:site_id/assets` - Create asset
- `PATCH /api/v1/webflow/sites/:site_id/assets/:asset_id` - Update asset
- `DELETE /api/v1/webflow/sites/:site_id/assets/:asset_id` - Delete asset

### Users
- `GET /api/v1/webflow/sites/:site_id/users` - List users
- `GET /api/v1/webflow/sites/:site_id/users/:user_id` - Get user
- `POST /api/v1/webflow/sites/:site_id/users` - Create user
- `PATCH /api/v1/webflow/sites/:site_id/users/:user_id` - Update user
- `DELETE /api/v1/webflow/sites/:site_id/users/:user_id` - Delete user

### Comments
- `GET /api/v1/webflow/sites/:site_id/comments` - List comments
- `GET /api/v1/webflow/sites/:site_id/comments/:comment_id` - Get comment
- `POST /api/v1/webflow/sites/:site_id/comments` - Create comment
- `PATCH /api/v1/webflow/sites/:site_id/comments/:comment_id` - Update comment
- `DELETE /api/v1/webflow/sites/:site_id/comments/:comment_id` - Delete comment

## Error Handling

The integration includes comprehensive error handling:

```ruby
begin
  result = webflow.create_item(site_id, collection_id, item_data)
rescue WebflowApiError => e
  puts "Error: #{e.message}"
  puts "Status Code: #{e.status_code}"
  puts "Response Body: #{e.response_body}"
end
```

Common error codes:
- `400` - Bad Request (Invalid parameters)
- `401` - Unauthorized (Check API token)
- `403` - Forbidden (Insufficient permissions)
- `404` - Not Found (Resource not found)
- `429` - Rate Limited (Too many requests)
- `500-599` - Server Error (Webflow API issue)

## Rate Limiting

The service implements automatic rate limiting:
- Maximum 60 requests per minute
- Automatic sleep when rate limit is reached
- Request tracking and logging

## Legacy Integration

The existing wrs integration has been preserved for backward compatibility:

```ruby
# Send a wrs to Webflow
wrs = Quotation.find(1)
WebflowService.new.send_wrs(wrs)
```

This method uses the configured `webflow_site_id` and `webflow_collection_id` from credentials.

## Testing

To test the integration:

1. Ensure your `WEBFLOW_TOKEN` is properly configured
2. Use the Rails console to test individual methods
3. Test API endpoints with tools like Postman or curl

Example curl commands:

```bash
# List sites
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     http://localhost:3000/api/v1/webflow/sites

# Create an item
curl -X POST \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"item":{"fieldData":{"name":"Test Item"}}}' \
     http://localhost:3000/api/v1/webflow/sites/SITE_ID/collections/COLLECTION_ID/items
```

## Security Considerations

1. **API Token Security**: Store the Webflow token in Rails credentials, never in code
2. **Rate Limiting**: The service automatically handles rate limiting to prevent API abuse
3. **Error Logging**: All API errors are logged for monitoring
4. **Authorization**: Add appropriate authorization checks in the controller as needed

## Troubleshooting

### Common Issues

1. **401 Unauthorized**: Check that your `WEBFLOW_TOKEN` is valid and has the correct permissions
2. **429 Rate Limited**: The service automatically handles this, but you may need to reduce request frequency
3. **404 Not Found**: Verify that site_id, collection_id, and other resource IDs are correct
4. **400 Bad Request**: Check that the request payload matches the expected format

### Debugging

Enable detailed logging by checking the Rails logs:

```ruby
# In Rails console
Rails.logger.level = Logger::DEBUG
```

The service logs all API requests and responses for debugging purposes. 