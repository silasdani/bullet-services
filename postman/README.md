# Webflow API Postman Collection

This Postman collection provides comprehensive testing for all Webflow REST API endpoints in your Rails application.

## 📥 Importing the Collection

1. **Download the Collection**
   - The collection file is located at: `postman/Webflow_API_Collection.json`

2. **Import into Postman**
   - Open Postman
   - Click "Import" button
   - Drag and drop the `Webflow_API_Collection.json` file
   - Or click "Upload Files" and select the file

## ⚙️ Configuration

### 1. Set Environment Variables

After importing, you need to configure the collection variables:

1. **Open Collection Variables**
   - Click on the collection name "Webflow API Collection"
   - Go to the "Variables" tab

2. **Update Required Variables**

   ```json
   {
     "base_url": "http://localhost:3000",
     "auth_token": "your_auth_token_here",
     "site_id": "your_site_id_here",
     "collection_id": "your_collection_id_here",
     "item_id": "your_item_id_here",
     "form_id": "your_form_id_here",
     "asset_id": "your_asset_id_here",
     "user_id": "your_user_id_here",
     "comment_id": "your_comment_id_here",
     "wrs_id": "your_wrs_id_here"
   }
   ```

### 2. Get Authentication Token

1. **Sign In First**
   - Use the "Authentication > Sign In" request
   - Update the email and password in the request body
   - Send the request

2. **Copy the Token**
   - From the response, copy the `access-token` value
   - Update the `auth_token` variable in the collection

### 3. Get Your Webflow IDs

Use the rake tasks to get your Webflow IDs:

```bash
# Get your sites
rake webflow:list_sites

# Get collections for a site
rake webflow:list_collections[your_site_id]

# Get items in a collection
rake webflow:list_items[your_site_id,your_collection_id]
```

## 🧪 Testing Workflow

### Step 1: Authentication
1. **Sign In** - Get your authentication token
2. **Update Variables** - Set the `auth_token` variable
3. **Test Authentication** - Try "Get Current User" to verify

### Step 2: Webflow Sites
1. **List Sites** - Get all your Webflow sites
2. **Get Site** - Test getting a specific site
3. **Update Variables** - Set the `site_id` variable

### Step 3: Collections
1. **List Collections** - Get collections for your site
2. **Create Collection** - Test creating a new collection
3. **Update Variables** - Set the `collection_id` variable
4. **Get Collection** - Test getting a specific collection
5. **Update Collection** - Test updating a collection

### Step 4: Collection Items
1. **List Items** - Get items in a collection
2. **Create Item** - Test creating a new item
3. **Update Variables** - Set the `item_id` variable
4. **Get Item** - Test getting a specific item
5. **Update Item** - Test updating an item
6. **Publish Items** - Test publishing items
7. **Delete Item** - Test deleting an item

### Step 5: Forms
1. **List Forms** - Get forms for your site
2. **Update Variables** - Set the `form_id` variable
3. **Get Form** - Test getting a specific form
4. **Create Form Submission** - Test form submissions

### Step 6: Assets
1. **List Assets** - Get assets for your site
2. **Create Asset** - Test creating a new asset
3. **Update Variables** - Set the `asset_id` variable
4. **Get Asset** - Test getting a specific asset
5. **Update Asset** - Test updating an asset
6. **Delete Asset** - Test deleting an asset

### Step 7: Users
1. **List Users** - Get users for your site
2. **Create User** - Test creating a new user
3. **Update Variables** - Set the `user_id` variable
4. **Get User** - Test getting a specific user
5. **Update User** - Test updating a user
6. **Delete User** - Test deleting a user

### Step 8: Comments
1. **List Comments** - Get comments for your site
2. **Create Comment** - Test creating a new comment
3. **Update Variables** - Set the `comment_id` variable
4. **Get Comment** - Test getting a specific comment
5. **Update Comment** - Test updating a comment
6. **Delete Comment** - Test deleting a comment

### Step 9: Quotations
1. **List Quotations** - Get all wrs
2. **Create Quotation** - Test creating a new wrs
3. **Update Variables** - Set the `wrs_id` variable
4. **Get Quotation** - Test getting a specific wrs
5. **Update Quotation** - Test updating a wrs
6. **Send to Webflow** - Test sending wrs to Webflow
7. **Delete Quotation** - Test deleting a wrs

## 🔧 Troubleshooting

### Common Issues

1. **401 Unauthorized**
   - Check that your `auth_token` is valid
   - Make sure you're signed in
   - Verify the token hasn't expired

2. **404 Not Found**
   - Check that your IDs are correct
   - Verify the resource exists
   - Make sure you have the right permissions

3. **422 Unprocessable Entity**
   - Check the request body format
   - Verify all required fields are present
   - Check field validation rules

4. **500 Server Error**
   - Check Rails server logs
   - Verify Webflow credentials are configured
   - Check if Webflow API is accessible

### Debug Steps

1. **Check Rails Logs**
   ```bash
   tail -f log/development.log
   ```

2. **Test Webflow Connection**
   ```bash
   rake webflow:test_connection
   ```

3. **Check Credentials**
   ```bash
   rake webflow:check_credentials
   ```

## 📋 Request Examples

### Authentication
```bash
# Sign In
POST {{base_url}}/auth/sign_in
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

### Create Collection Item
```bash
# Create Item
POST {{base_url}}/api/v1/webflow/sites/{{site_id}}/collections/{{collection_id}}/items
Content-Type: application/json

{
  "item": {
    "fieldData": {
      "name": "Test Item",
      "description": "This is a test item",
      "price": 99.99,
      "status": "active"
    },
    "isArchived": false,
    "isDraft": false
  }
}
```

### Send Quotation to Webflow
```bash
# Send Quotation
POST {{base_url}}/api/v1/wrs/{{wrs_id}}/send_to_webflow
```

## 🚀 Quick Start

1. **Import the collection**
2. **Set up variables** (especially `base_url` and `auth_token`)
3. **Sign in** to get your token
4. **Test the connection** with "List Sites"
5. **Run through the workflow** step by step

## 📊 Expected Responses

### Successful Response
```json
{
  "sites": [
    {
      "_id": "site_id",
      "name": "My Site",
      "shortName": "mysite",
      "createdOn": "2024-01-01T00:00:00.000Z"
    }
  ]
}
```

### Error Response
```json
{
  "error": "Unauthorized - Check your API token",
  "status_code": 401
}
```

## 🔐 Security Notes

- **Never commit tokens** to version control
- **Use environment variables** for sensitive data
- **Rotate tokens** regularly
- **Test with dummy data** first
- **Monitor API usage** to avoid rate limits

## 📚 Additional Resources

- [Webflow API Documentation](https://developers.webflow.com/)
- [Rails API Documentation](https://guides.rubyonrails.org/api_app.html)
- [Postman Learning Center](https://learning.postman.com/)

## 🆘 Support

If you encounter issues:

1. Check the Rails server logs
2. Verify your Webflow credentials
3. Test individual endpoints
4. Check the API documentation
5. Review the error responses

Happy testing! 🎉 