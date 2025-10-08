# Webflow Webhooks Setup

This document explains how to set up Webflow webhooks to automatically sync changes from Webflow back to your Rails application.

## Overview

When a WRS item is updated in Webflow (either through the Webflow UI or API), the webhook will automatically trigger a sync to update your Rails database with the latest data from Webflow.

## Webhook Endpoint

```
POST https://your-domain.com/api/v1/webhooks/webflow/collection_item_changed
```

**For local development:**
```
POST http://localhost:3000/api/v1/webhooks/webflow/collection_item_changed
```

## Setup Instructions

### 1. Configure Webhook Secret (Optional but Recommended)

Add a webhook secret to your Rails credentials for security:

```bash
rails credentials:edit
```

Add the following:

```yaml
WEBFLOW_WEBHOOK_SECRET: "your_secure_random_secret_here"
```

Generate a secure random secret:
```bash
rails secret
```

### 2. Set Up Webhook in Webflow

1. Go to your Webflow site settings
2. Navigate to **Integrations** → **Webhooks**
3. Click **Add Webhook**
4. Configure the webhook:
   - **Trigger Type**: `Collection Item Changed`
   - **Collection**: Select your WRS collection
   - **Webhook URL**: `https://your-domain.com/api/v1/webhooks/webflow/collection_item_changed`
   - **Filter** (optional): Configure filters if needed

### 3. For Local Development (using ngrok)

To test webhooks locally, you'll need to expose your local server:

```bash
# Install ngrok if you haven't already
# https://ngrok.com/download

# Start your Rails server
rails s

# In another terminal, start ngrok
ngrok http 3000
```

Use the ngrok URL in your Webflow webhook settings:
```
https://your-ngrok-url.ngrok.io/api/v1/webhooks/webflow/collection_item_changed
```

## How It Works

### Webhook Flow

1. **Change in Webflow**: A WRS item is created, updated, or published in Webflow
2. **Webhook Triggered**: Webflow sends a POST request to your webhook endpoint with complete item data
3. **Signature Verification**: The webhook verifies the request is from Webflow (if secret is configured)
4. **Timestamp Validation**: The webhook validates the timestamp to prevent replay attacks
5. **Sync to Rails**: Uses `WrsSyncService` to update the Rails database with the webhook payload data
6. **Response**: Returns success/failure status to Webflow

**Note:** The webhook uses the complete item data included in the webhook payload, so no additional API calls to Webflow are needed. This makes the webhook faster and avoids rate limiting issues.

### Circular Sync Prevention

To prevent infinite webhook loops, the system implements circular sync prevention:

1. **Webflow → Rails**: When a webhook receives data from Webflow, it sets the `skip_webflow_sync` flag on the WRS record
2. **Auto-sync Skipped**: The auto-sync callback checks this flag and skips syncing back to Webflow
3. **No Loop**: This prevents the webhook from triggering another auto-sync, which would trigger another webhook, etc.

**Flow:**
```
✅ Webflow Update → Webhook → Rails Update (skip_webflow_sync=true) → No auto-sync → Done
✅ Rails Update → Auto-sync → Webflow Update → Webhook → Rails Update (skip_webflow_sync=true) → No loop
```

Without this protection, you would get an infinite loop:
```
❌ Webflow Update → Webhook → Rails Update → Auto-sync → Webflow Update → Webhook → Loop forever!
```

### What Gets Synced

The webhook syncs all WRS data including:
- Basic information (name, address, slug, etc.)
- Status and pricing
- Publication status (`is_draft`, `last_published`)
- All windows and their locations
- All tools and prices for each window
- Image URLs
- Timestamps (created, updated, published)

**Important**: The sync service only creates windows that have **both** a location **and** items/tools. This prevents duplicate empty windows from being created when Webflow sends empty fields from its CMS collection structure.

## Webhook Payload

Webflow v2 sends a payload like this:

```json
{
  "triggerType": "collection_item_changed",
  "payload": {
    "id": "item_id_here",
    "siteId": "site_id_here",
    "workspaceId": "workspace_id_here",
    "collectionId": "collection_id_here",
    "cmsLocaleId": null,
    "lastPublished": "2025-10-08T18:42:53.309Z",
    "lastUpdated": "2025-10-08T18:42:53.309Z",
    "createdOn": "2025-10-08T16:33:15.200Z",
    "isArchived": false,
    "isDraft": false,
    "fieldData": {
      "name": "Item Name",
      "slug": "item-slug",
      ...
    }
  }
}
```

The webhook extracts the item ID from `payload.id` and uses the complete item data included in the webhook payload. This includes all field data, timestamps, and publication status, so no additional API calls are needed.

## Security

### Webhook Signature Verification

If `WEBFLOW_WEBHOOK_SECRET` is configured, the webhook verifies incoming requests using HMAC-SHA256:

1. Webflow sends an `X-Webflow-Signature` header and an `X-Webflow-Timestamp` header
2. The webhook computes the expected signature as: `HMAC-SHA256(timestamp + ":" + body, secret)`
   - Note: The timestamp and body are separated by a colon (`:`)
3. If signatures match, the request is processed
4. If signatures don't match, the request is rejected with 401 Unauthorized

**Important Notes:**
- Without a webhook secret, any request to the webhook endpoint will be processed. Always use a webhook secret in production!
- Webhooks created via OAuth applications include signatures. Webhooks set up through a site's dashboard or using a Site's API Key do not include signatures.
- The webhook secret should be your OAuth application's client secret (not the site API key).

### Timestamp Validation (Replay Attack Prevention)

To prevent replay attacks, the webhook validates that the timestamp is within 5 minutes of the current server time:

1. The `X-Webflow-Timestamp` is checked against the current server time
2. If the difference is greater than 5 minutes, the webhook is rejected
3. This ensures that captured webhook payloads cannot be replayed later

**Important:** Ensure your server's clock is synchronized (e.g., using NTP) to avoid false rejections.

## Monitoring

### Logs

All webhook activity is logged:

```ruby
# Check your Rails logs
tail -f log/development.log | grep "Webflow Webhook"
```

Log entries include:
- ✅ Successful syncs: `Webflow Webhook: Successfully synced WRS #123`
- ❌ Failed syncs: `Webflow Webhook: Failed to sync item`
- ⚠️ Invalid signatures: `Webflow Webhook: Invalid signature`

### Testing the Webhook

You can test the webhook manually:

```bash
# Without signature (only works if WEBFLOW_WEBHOOK_SECRET is not set)
curl -X POST http://localhost:3000/api/v1/webhooks/webflow/collection_item_changed \
  -H "Content-Type: application/json" \
  -d '{"payload": {"id": "your_webflow_item_id"}}'

# With signature (if you have a secret configured)
PAYLOAD='{"payload": {"id": "your_webflow_item_id"}}'
TIMESTAMP=$(date +%s)000  # Webflow uses milliseconds
SIGNED_PAYLOAD="${TIMESTAMP}:${PAYLOAD}"  # Note the colon separator
SIGNATURE=$(echo -n "$SIGNED_PAYLOAD" | openssl dgst -sha256 -hmac "your_webhook_secret" | cut -d' ' -f2)

curl -X POST http://localhost:3000/api/v1/webhooks/webflow/collection_item_changed \
  -H "Content-Type: application/json" \
  -H "X-Webflow-Signature: $SIGNATURE" \
  -H "X-Webflow-Timestamp: $TIMESTAMP" \
  -d "$PAYLOAD"
```

## Troubleshooting

### Webhook Not Firing

1. Check that the webhook is active in Webflow
2. Verify the URL is correct (no trailing slashes)
3. Check that your server is accessible from the internet
4. Review Webflow's webhook logs in the Webflow dashboard

### Sync Failures

Common issues:
- **Missing required fields**: WRS must have `name`, `address`, and `slug`
- **Invalid item ID**: The item might not exist in the webhook payload
- **User not found**: Default admin user must exist for new WRS items
- **Rate limiting**: If you see 429 errors, the webhook might be configured incorrectly or there may be other API calls happening

Check the logs for specific error messages.

**Note:** The webhook no longer makes additional API calls to fetch item data since Webflow v2 includes complete item data in the webhook payload. This eliminates rate limiting issues from webhook processing.

### Duplicate Windows Issue

If you're seeing duplicate or empty windows being created:

**Cause**: Webflow's CMS collection has fields for multiple windows (windows 1-5) in its schema. When the webhook sends data, it includes ALL fields from the collection, even empty ones. 

**Solution**: The sync service now validates that a window has **both** a location **AND** items before creating it. Empty windows with just a location field are skipped.

**Debugging**: Enable debug logging to see exactly what windows are being detected and created:

```ruby
# In Rails console or logs
Rails.logger.level = :debug
```

You'll see output like:
```
WrsSyncService: Preparing window data from field_data
  Available window-related fields: window-location, window-1-items-2, window-1-items-prices-3, window-2-location...
  Window 1: Found location='Rear Elevation'
    Items: "Conservation joint repair x1"
    Prices: "110.0"
  Window 1: ✓ Added to sync list
  Window 2: No valid location (window-2-location="")
  Window 3: Found location='Front Door'
    Items: ""
    Prices: ""
  Window 3: Skipping - has location='Front Door' but no items
WrsSyncService: Prepared 1 window(s) from Webflow data
  Window 1: location='Rear Elevation', items=1, prices=1
```

### Signature Verification Failing

- Ensure `WEBFLOW_WEBHOOK_SECRET` matches the secret in Webflow
- Verify the secret is properly configured in Rails credentials
- Check that the header name is exactly `X-Webflow-Signature`

## Best Practices

1. **Always use a webhook secret in production** for security
2. **Monitor webhook logs** to catch sync issues early
3. **Handle webhook failures gracefully** - Webflow will retry failed webhooks
4. **Test webhooks in development** before deploying to production
5. **Keep sync logic idempotent** - webhooks may be called multiple times for the same event
6. **Circular sync prevention is automatic** - the system prevents infinite loops between Webflow and Rails
7. **Draft-only auto-sync** - only draft items auto-sync to Webflow to protect published content

## Integration with Publish/Unpublish

The webhook works seamlessly with the publish/unpublish endpoints:

1. **User publishes WRS** → Rails pushes to Webflow → Webflow webhook fires → Rails syncs back
2. **User edits in Webflow** → Webflow webhook fires → Rails automatically updates
3. **Always in sync**: Changes from either side are reflected in both systems

This creates a bi-directional sync between Rails and Webflow! 🔄

