# FreshBooks OAuth Production Setup Guide

This guide walks you through setting up FreshBooks OAuth authentication in production using rake tasks.

## Prerequisites

1. **FreshBooks Developer Account**
   - Go to https://my.freshbooks.com/#/developer
   - Create a new OAuth application
   - Note your `CLIENT_ID` and `CLIENT_SECRET`

2. **Production Environment Variables**
   Ensure these are set in your production environment:
   ```bash
   FRESHBOOKS_CLIENT_ID=your_client_id
   FRESHBOOKS_CLIENT_SECRET=your_client_secret
   FRESHBOOKS_REDIRECT_URI=https://your-production-domain.com/freshbooks/callback
   ```

   ⚠️ **Important**: The `FRESHBOOKS_REDIRECT_URI` must match **exactly** what you register in FreshBooks (including protocol, domain, path, and trailing slashes).

## Step-by-Step Production Setup

### Step 1: Verify Configuration

Before starting, verify your OAuth credentials are configured:

```bash
rails freshbooks:verify_config
```

This will check:
- ✅ Client ID is set
- ✅ Client Secret is set
- ✅ Redirect URI is set
- ✅ Callback endpoint accessibility

**Expected Output:**
```
Checking FreshBooks OAuth configuration...

✅ Client ID: abc123def...
✅ Client Secret: SET
✅ Redirect URI: https://your-production-domain.com/freshbooks/callback

✅ All OAuth credentials are configured!
```

If any items are missing, set the environment variables and try again.

### Step 2: Get Authorization URL

Generate the OAuth authorization URL:

```bash
rails freshbooks:show_auth_url
```

**Expected Output:**
```
OAuth Authorization URL:
https://auth.freshbooks.com/oauth/authorize?client_id=YOUR_CLIENT_ID&response_type=code&redirect_uri=https%3A%2F%2Fyour-production-domain.com%2Ffreshbooks%2Fcallback

⚠️  Before visiting:
   Ensure this redirect_uri is registered in FreshBooks: https://your-production-domain.com/freshbooks/callback
   Register at: https://my.freshbooks.com/#/developer

   After authorization, copy the 'code' parameter and run:
   rails freshbooks:exchange_code[CODE]
```

### Step 3: Authorize Application

1. **Copy the authorization URL** from Step 2
2. **Open it in a browser** (you must be logged into FreshBooks)
3. **Authorize the application** - FreshBooks will show a permissions screen
4. **You'll be redirected** to your production callback URL with a `code` parameter:
   ```
   https://your-production-domain.com/freshbooks/callback?code=AUTHORIZATION_CODE&state=...
   ```
5. **Copy the `code` parameter** from the URL (it's a long string)

⚠️ **Important Notes:**
- Authorization codes expire in ~10 minutes
- Each code can only be used once
- Make sure you're logged into the correct FreshBooks account

### Step 4: Exchange Code for Tokens

Exchange the authorization code for access and refresh tokens:

```bash
rails freshbooks:exchange_code[YOUR_AUTHORIZATION_CODE]
```

Replace `YOUR_AUTHORIZATION_CODE` with the code from Step 3.

**Expected Output:**
```
Exchanging authorization code for tokens...
  Code length: 64

Configuration:
  Client ID: abc123def...
  Client Secret: SET
  Redirect URI: https://your-production-domain.com/freshbooks/callback

✅ Success! Tokens have been saved to the database.

Business ID: abc123
Token expires in: 3600 seconds (1.0 hours)

Optional: Add these to your .env file if you prefer environment variables:

FRESHBOOKS_ACCESS_TOKEN=your_access_token_here
FRESHBOOKS_REFRESH_TOKEN=your_refresh_token_here
FRESHBOOKS_BUSINESS_ID=abc123
```

**What Happens:**
- ✅ Tokens are automatically saved to the `freshbooks_tokens` database table
- ✅ Business ID is extracted and stored
- ✅ Token expiration is calculated and saved
- ✅ You can now use FreshBooks API features

### Step 5: Verify Connection

Test that the connection is working:

```bash
rails freshbooks:test
```

**Expected Output:**
```
Testing FreshBooks connection...
Business ID: abc123

Testing API endpoint...
Response code: 200
✅ Connection successful!
Found 5 clients
```

If you see errors:
- Check that tokens were saved correctly
- Verify the business ID is correct
- Review error messages for specific issues

## Token Management

### Token Lifecycle (FreshBooks)

| Token Type        | Lifespan              | Notes                                                                 |
|-------------------|-----------------------|-----------------------------------------------------------------------|
| **Access token**  | 12 hours              | API calls return 401 Unauthorized after expiry                       |
| **Authorization code** | 5 minutes         | One-time use; exchange for tokens immediately                        |
| **Refresh token** | One-time use          | Each refresh returns a new refresh token; store it for next refresh   |

**Best practice:** Refresh the access token proactively (at least once every 12 hours). This app refreshes 1 hour before expiry.

### Automatic Token Refresh

Tokens are automatically refreshed when:
- API calls return 401 Unauthorized
- Token is about to expire (within 1 hour)
- Using `Freshbooks::BaseClient` services

### Manual Token Refresh

If you need to manually refresh tokens:

```bash
rails freshbooks:refresh_token
```

**Required Environment Variables:**
- `FRESHBOOKS_REFRESH_TOKEN` - Your current refresh token (or stored in database)
- `FRESHBOOKS_CLIENT_ID` - Your OAuth client ID
- `FRESHBOOKS_CLIENT_SECRET` - Your OAuth client secret
- `FRESHBOOKS_REDIRECT_URI` - Must match the URI used during authorization

**Expected Output:**
```
Refreshing access token...

✅ Token refreshed!

Update your .env file:

FRESHBOOKS_ACCESS_TOKEN=new_access_token_here
FRESHBOOKS_REFRESH_TOKEN=new_refresh_token_here

Token expires in: 3600 seconds (1.0 hours)
```

**Note:** If tokens are stored in the database, they'll be automatically updated. If using environment variables, update them manually.

### Get Business ID from Existing Token

If you have an access token but need the business ID:

```bash
rails freshbooks:get_business_id
```

**Required:** `FRESHBOOKS_ACCESS_TOKEN` environment variable or existing token in database

**Expected Output:**
```
Fetching business ID...

✅ Business ID found: abc123

Add to your .env file:
FRESHBOOKS_BUSINESS_ID=abc123

✅ Updated database record
```

## Troubleshooting

### "Authorization code expired"

**Problem:** Authorization codes expire in ~10 minutes.

**Solution:** Start the OAuth flow again from Step 2.

### "Code already used"

**Problem:** Each authorization code can only be used once.

**Solution:** Get a new authorization code by visiting the authorization URL again.

### "Redirect URI mismatch"

**Problem:** The redirect URI doesn't match what's registered in FreshBooks.

**Solution:**
1. Check `FRESHBOOKS_REDIRECT_URI` environment variable
2. Verify it matches **exactly** in FreshBooks app settings (including protocol, domain, path, trailing slashes)
3. Update FreshBooks app settings if needed: https://my.freshbooks.com/#/developer

### "FreshBooks OAuth credentials not configured"

**Problem:** Missing required environment variables.

**Solution:** Set all three required variables:
```bash
FRESHBOOKS_CLIENT_ID=your_client_id
FRESHBOOKS_CLIENT_SECRET=your_client_secret
FRESHBOOKS_REDIRECT_URI=https://your-production-domain.com/freshbooks/callback
```

### "Could not fetch business_id from FreshBooks API"

**Problem:** API call to get business information failed.

**Solution:**
1. Verify access token is valid
2. Check API permissions in FreshBooks app settings
3. Try refreshing the token

### "Cannot reach callback endpoint"

**Problem:** The callback URL is not accessible.

**Solution:**
1. Verify your production server is running
2. Check that the `/freshbooks/callback` route is accessible
3. Test the callback URL manually in a browser
4. Check firewall/security group settings

### Token Refresh Failing

**Problem:** Refresh token is invalid or expired.

**Solution:**
1. Re-authorize the application (start from Step 2)
2. Verify `FRESHBOOKS_CLIENT_ID` and `FRESHBOOKS_CLIENT_SECRET` are correct
3. Check FreshBooks API status

## Quick Reference

### All Available Rake Tasks

```bash
# Verify OAuth configuration
rails freshbooks:verify_config

# Show authorization URL
rails freshbooks:show_auth_url

# Exchange authorization code for tokens
rails freshbooks:exchange_code[YOUR_CODE]

# Test FreshBooks connection
rails freshbooks:test

# Refresh access token
rails freshbooks:refresh_token

# Get business ID from token
rails freshbooks:get_business_id
```

### Required Environment Variables

```bash
# OAuth Credentials (Required for setup)
FRESHBOOKS_CLIENT_ID=your_client_id
FRESHBOOKS_CLIENT_SECRET=your_client_secret
FRESHBOOKS_REDIRECT_URI=https://your-production-domain.com/freshbooks/callback

# Tokens (Optional - stored in database by default)
FRESHBOOKS_ACCESS_TOKEN=your_access_token
FRESHBOOKS_REFRESH_TOKEN=your_refresh_token
FRESHBOOKS_BUSINESS_ID=your_business_id
```

## Security Best Practices

1. **Never commit tokens to version control**
   - Use environment variables or secure secret management
   - Tokens are stored in database by default (more secure)

2. **Use HTTPS for all OAuth callbacks**
   - Required for production environments
   - FreshBooks requires HTTPS for production redirect URIs

3. **Rotate tokens regularly**
   - Refresh tokens periodically
   - Re-authorize if refresh tokens are compromised

4. **Limit access to OAuth credentials**
   - Only admins should have access to OAuth setup
   - Use environment variable management tools (e.g., AWS Secrets Manager, HashiCorp Vault)

5. **Monitor token expiration**
   - Set up alerts for token expiration
   - Automate token refresh where possible

## Online Payments ("Pay Invoice" in Emails)

To show **Pay Invoice** instead of **View Invoice** when sending invoices:

1. **Enable Advanced Payments** in FreshBooks (Add-ons → Advanced Payments)
2. **Connect a payment gateway** (Stripe or PayPal) in FreshBooks Settings
3. **Add OAuth scopes** in your app at https://my.freshbooks.com/#/developer:
   - `user:online_payments:read`
   - `user:online_payments:write`
4. **Re-authorize** the app (revoke existing token, then run `rails freshbooks:show_auth_url` and complete OAuth again)

Without these, invoices will still send but emails will show "View Invoice" instead of "Pay Invoice".

## Next Steps

After successful setup:

1. ✅ **Test API Integration**
   ```bash
   rails freshbooks:test
   ```

2. ✅ **Sync Clients** (via API endpoint)
   ```bash
   curl -X POST "https://your-domain.com/api/v1/freshbooks/sync_clients" \
     -H "Authorization: Bearer ADMIN_TOKEN"
   ```

3. ✅ **Check Connection Status** (via API endpoint)
   ```bash
   curl -X GET "https://your-domain.com/api/v1/freshbooks/status" \
     -H "Authorization: Bearer ADMIN_TOKEN"
   ```

4. ✅ **Monitor Token Expiration**
   - Tokens auto-refresh, but monitor logs for issues
   - Set up alerts for refresh failures

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review FreshBooks API documentation: https://www.freshbooks.com/api/authentication
3. Verify your FreshBooks app settings: https://my.freshbooks.com/#/developer
4. Check application logs for detailed error messages

