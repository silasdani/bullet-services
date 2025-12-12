# FreshBooks Integration Guide

Complete guide for integrating FreshBooks into your Rails application for automatic invoice generation and payment tracking.

## Table of Contents

1. [Overview](#overview)
2. [OAuth Setup](#oauth-setup)
3. [Environment Variables](#environment-variables)
4. [Database Setup](#database-setup)
5. [Usage](#usage)
6. [API Reference](#api-reference)
7. [Webhooks](#webhooks)
8. [Error Handling](#error-handling)
9. [Troubleshooting](#troubleshooting)

## Overview

This integration allows you to:
- ✅ **Automatically create invoices** in FreshBooks when users submit forms
- ✅ **Generate payment links** for clients to pay online
- ✅ **Send invoices via email** with payment links included
- ✅ **Receive webhook notifications** when invoices are paid
- ✅ **Track payment status** and update your local records

**Key Features:**
- Single app-level OAuth connection (tokens provided via environment variables or database)
- Automatic token refresh
- Background job support for syncing data
- Webhook signature verification
- Production-ready error handling

## OAuth Setup

To use the FreshBooks API, you need to obtain access tokens through OAuth2. This is a one-time setup.

### Quick Setup (Using Rake Task)

#### Step 1: Get Authorization Code

1. Visit this URL in your browser (with your actual credentials):

```
https://auth.freshbooks.com/oauth/authorize?client_id=YOUR_CLIENT_ID&response_type=code&redirect_uri=YOUR_REDIRECT_URI
```

**Example with your credentials:**
```
https://auth.freshbooks.com/oauth/authorize?client_id=db7dc00b0f0460607fe944d48f711b5e4218d0264c34bab5dff3bc38840e0d7f&response_type=code&redirect_uri=https://fb133ddd2e97.ngrok-free.app/freshbooks/callback
```

2. Log in to FreshBooks and authorize the application
3. You'll be redirected to your callback URL with a `code` parameter:
   ```
   https://fb133ddd2e97.ngrok-free.app/freshbooks/callback?code=AUTHORIZATION_CODE_HERE
   ```
4. Copy the `code` value from the URL

#### Step 2: Exchange Code for Tokens

Run the rake task with your authorization code:

```bash
rails freshbooks:exchange_code[AUTHORIZATION_CODE_HERE]
```

This will:
- Exchange the code for access and refresh tokens
- Fetch your business ID
- Display the tokens you need to add to your `.env` file
- Optionally save tokens to the database

#### Step 3: Add Tokens to Environment

Copy the output and add to your `.env` file:

```bash
FRESHBOOKS_ACCESS_TOKEN=your_access_token_here
FRESHBOOKS_REFRESH_TOKEN=your_refresh_token_here
FRESHBOOKS_BUSINESS_ID=your_business_id_here
```

### Manual Setup (Alternative)

If you prefer to do it manually:

#### Step 1: Get Authorization Code

Same as above - visit the OAuth URL and get the code.

#### Step 2: Exchange Code for Tokens

Use curl or Postman:

```bash
curl -X POST https://auth.freshbooks.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "authorization_code",
    "code": "YOUR_AUTHORIZATION_CODE",
    "client_id": "db7dc00b0f0460607fe944d48f711b5e4218d0264c34bab5dff3bc38840e0d7f",
    "client_secret": "f6f3dc91eed8c0ff42c1b8c79f08cc4eb00f9e6c04e4e3a7261eadb1a204b8e2",
    "redirect_uri": "https://fb133ddd2e97.ngrok-free.app/freshbooks/callback"
  }'
```

Response:
```json
{
  "access_token": "your_access_token",
  "refresh_token": "your_refresh_token",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

#### Step 3: Get Business ID

```bash
curl -X GET https://api.freshbooks.com/auth/api/v1/users/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Api-Version: alpha"
```

Look for `business_id` or `account_id` in the response.

### Testing Your Setup

After setting up tokens, test the connection:

```bash
rails freshbooks:test
```

### Refreshing Tokens

Access tokens expire (usually after 1 hour). To refresh manually:

```bash
rails freshbooks:refresh_token
```

**Note:** The integration automatically refreshes tokens when they expire, so you typically don't need to do this manually.

## Environment Variables

Add these to your `.env` file or Rails credentials:

```bash
# OAuth Credentials (for token refresh)
FRESHBOOKS_CLIENT_ID=your_client_id
FRESHBOOKS_CLIENT_SECRET=your_client_secret
FRESHBOOKS_REDIRECT_URI=https://yourdomain.com/freshbooks/callback

# Tokens (get these from OAuth flow)
FRESHBOOKS_ACCESS_TOKEN=your_access_token
FRESHBOOKS_REFRESH_TOKEN=your_refresh_token
FRESHBOOKS_BUSINESS_ID=your_business_id

# Webhook (optional but recommended)
FRESHBOOKS_WEBHOOK_SECRET=your_webhook_secret
```

### Token Management Options

**Option 1: Environment Variables** (Recommended for simplicity)
- Set `FRESHBOOKS_ACCESS_TOKEN`, `FRESHBOOKS_BUSINESS_ID`
- Tokens are read from environment on each request

**Option 2: Database Storage**
- Store tokens in `freshbooks_tokens` table
- Supports automatic token refresh
- Better for multi-instance deployments

The service automatically uses database tokens if available, otherwise falls back to environment variables.

## Database Setup

### Run Migrations

```bash
rails db:migrate
```

This creates:
- `freshbooks_tokens` - Stores OAuth tokens (single record)
- `freshbooks_clients` - Synced client data
- `freshbooks_invoices` - Synced invoice data
- `freshbooks_payments` - Synced payment data

### Optional: Store Tokens in Database

If you prefer storing tokens in the database:

```ruby
FreshbooksToken.create!(
  access_token: 'your_access_token',
  refresh_token: 'your_refresh_token',
  token_expires_at: 1.hour.from_now,
  business_id: 'your_business_id'
)
```

## Usage

### Creating Invoices

#### Basic Usage

```ruby
invoice = Invoice.find(123)

# Create invoice in FreshBooks
result = invoice.create_in_freshbooks!(
  client_id: 'freshbooks_client_id',
  lines: [
    {
      name: 'Window Repair Service',
      description: 'Repair of 5 windows',
      quantity: 1,
      cost: 500.00
    }
  ]
)

# Access payment link
payment_link = result[:payment_link]
# => "https://my.freshbooks.com/view/business_id/invoice_id"
```

#### With Email Sending

```ruby
invoice.create_in_freshbooks!(
  client_id: 'freshbooks_client_id',
  lines: [
    {
      name: 'Service Name',
      description: 'Service description',
      quantity: 1,
      cost: 100.00
    }
  ],
  send_email: true,
  email_to: 'client@example.com'
)
```

This will:
1. Create the invoice in FreshBooks
2. Generate a payment link
3. Send an email to the client with the invoice and payment link

#### Using the Service Directly

```ruby
service = Freshbooks::InvoiceCreationService.new(
  invoice: invoice,
  client_id: 'freshbooks_client_id',
  lines: [
    {
      name: 'Service Name',
      description: 'Service description',
      quantity: 1,
      cost: 100.00
    }
  ],
  send_email: true,
  email_to: 'client@example.com'
)

result = service.call
if service.success?
  payment_link = result[:payment_link]
  # Use payment_link to send to client
else
  errors = service.errors
end
```

### Payment Links

After creating an invoice, you get a payment link:

```ruby
result = invoice.create_in_freshbooks!(client_id: 'client_id', lines: [...])
payment_link = result[:payment_link]

# Send to client via email, SMS, or display in your app
```

The payment link allows clients to:
- View the invoice
- Pay online via credit card, bank transfer, etc.
- Download PDF

### Example: Form Submission Flow

```ruby
# In your controller
class InvoicesController < Api::V1::BaseController
  def create
    @invoice = Invoice.new(invoice_params)
    
    if @invoice.save
      # Create in FreshBooks
      result = @invoice.create_in_freshbooks!(
        client_id: find_or_create_freshbooks_client(@invoice),
        lines: build_invoice_lines(@invoice),
        send_email: true,
        email_to: @invoice.client_email
      )
      
      # Return payment link to frontend
      render json: {
        invoice: @invoice,
        payment_link: result[:payment_link]
      }
    end
  end
  
  private
  
  def find_or_create_freshbooks_client(invoice)
    # Your logic to find or create FreshBooks client
    clients = Freshbooks::Clients.new
    existing_client = clients.list.dig(:clients).find { |c| c['email'] == invoice.client_email }
    
    if existing_client
      existing_client['id']
    else
      new_client = clients.create(
        email: invoice.client_email,
        first_name: invoice.client_first_name,
        last_name: invoice.client_last_name
      )
      new_client['id']
    end
  end
  
  def build_invoice_lines(invoice)
    [
      {
        name: invoice.name,
        description: invoice.description,
        quantity: 1,
        cost: invoice.total_amount
      }
    ]
  end
end
```

## API Reference

### Freshbooks::Invoices

```ruby
invoices = Freshbooks::Invoices.new

# Create invoice
invoice_data = invoices.create(
  client_id: 'client_id',
  date: Date.current,
  due_date: 30.days.from_now,
  currency: 'USD',
  lines: [
    { name: 'Service', cost: 100.00, quantity: 1 }
  ]
)

# Get invoice
invoice = invoices.get('invoice_id')

# Get payment link
payment_link = invoices.get_payment_link('invoice_id')

# Send invoice by email
invoices.send_by_email(
  'invoice_id',
  email: 'client@example.com',
  subject: 'Your Invoice',
  message: 'Please pay using the link below'
)

# Get PDF
pdf_url = invoices.get_pdf('invoice_id')
```

### Freshbooks::Clients

```ruby
clients = Freshbooks::Clients.new

# List clients
result = clients.list(page: 1, per_page: 100)
clients_list = result[:clients]

# Get client
client = clients.get('client_id')

# Create client
new_client = clients.create(
  email: 'client@example.com',
  first_name: 'John',
  last_name: 'Doe',
  organization: 'Company Inc'
)

# Update client
clients.update('client_id', first_name: 'Jane')
```

### Freshbooks::Payments

```ruby
payments = Freshbooks::Payments.new

# List payments
result = payments.list(page: 1, per_page: 100, invoice_id: 'invoice_id')

# Get payment
payment = payments.get('payment_id')

# Create payment
payment = payments.create(
  invoice_id: 'invoice_id',
  amount: 100.00,
  date: Date.current,
  payment_method: 'Credit Card'
)
```

### API Endpoints

#### Connection Status
```
GET /api/v1/freshbooks/status
```

#### Manual Sync
```
POST /api/v1/freshbooks/sync_clients
POST /api/v1/freshbooks/sync_invoices
POST /api/v1/freshbooks/sync_payments
```

#### Create Invoice
```
POST /api/v1/freshbooks/create_invoice
{
  "invoice_id": 123,
  "client_id": "freshbooks_client_id",
  "lines": [
    {
      "name": "Service",
      "description": "Description",
      "quantity": 1,
      "cost": 100.00
    }
  ]
}
```

## Webhooks

When a client pays an invoice, FreshBooks sends a webhook to notify your application.

### Webhook Endpoint

```
POST /api/v1/webhooks/freshbooks
```

### Webhook Events Handled

- `payment.create` - Invoice was paid
- `payment.updated` - Payment was updated
- `invoice.create` - New invoice created
- `invoice.updated` - Invoice was updated

### What Happens

1. Webhook verifies signature (if `FRESHBOOKS_WEBHOOK_SECRET` is set)
2. Updates `FreshbooksInvoice` status to 'paid'
3. Updates linked `Invoice` record (if exists)
4. Creates `FreshbooksPayment` record

### Example Webhook Payload

```json
{
  "event": "payment.create",
  "object": {
    "id": "payment_id",
    "invoiceid": "invoice_id",
    "amount": {
      "amount": "500.00",
      "code": "USD"
    },
    "date": "2025-01-15",
    "type": "Credit Card"
  }
}
```

### Setting Up Webhooks in FreshBooks

FreshBooks webhooks are registered via API, not through the website UI. Use the rake tasks to register them:

#### Option 1: Register Payment Webhook (Recommended)

```bash
# Set your webhook URL (or it will prompt you)
WEBHOOK_URL=https://yourdomain.com/api/v1/webhooks/freshbooks rails freshbooks:webhooks:register_payment
```

This will:
- Register a webhook for `payment.create` events
- Generate a webhook secret (verifier)
- Display the secret to add to your `.env` file

#### Option 2: Register All Webhooks

```bash
WEBHOOK_URL=https://yourdomain.com/api/v1/webhooks/freshbooks rails freshbooks:webhooks:register_all
```

This registers webhooks for:
- `payment.create`
- `payment.updated`
- `invoice.create`
- `invoice.updated`

#### Option 3: List Registered Webhooks

```bash
rails freshbooks:webhooks:list
```

#### Option 4: Delete a Webhook

```bash
rails freshbooks:webhooks:delete[WEBHOOK_ID]
```

#### For Local Development (ngrok)

If testing locally with ngrok:

```bash
# Start ngrok
ngrok http 3000

# Register webhook with ngrok URL
WEBHOOK_URL=https://your-ngrok-url.ngrok.io/api/v1/webhooks/freshbooks rails freshbooks:webhooks:register_payment
```

**Note:** After registering, FreshBooks will send a verification request to your webhook URL. The webhook controller automatically handles this verification.

### Setting Up Webhook Secret

Generate a random secret:

```bash
openssl rand -hex 32
```

Add to `.env`:
```bash
FRESHBOOKS_WEBHOOK_SECRET=your_generated_secret_here
```

Configure the same secret in FreshBooks webhook settings.

## Error Handling

All FreshBooks API errors raise `FreshbooksError`:

```ruby
begin
  invoice.create_in_freshbooks!(client_id: 'client_id', lines: [...])
rescue FreshbooksError => e
  Rails.logger.error "FreshBooks error: #{e.message}"
  Rails.logger.error "Status: #{e.status_code}" if e.status_code
  Rails.logger.error "Response: #{e.response_body}" if e.response_body
  # Handle error
end
```

## Troubleshooting

### OAuth Issues

#### "Invalid redirect_uri"
- Make sure the redirect URI in your request matches exactly what's configured in FreshBooks
- Check for trailing slashes, http vs https, etc.

#### "Invalid authorization code"
- Authorization codes expire quickly (usually within 10 minutes)
- Get a fresh code and try again

#### "Invalid client credentials"
- Double-check your `FRESHBOOKS_CLIENT_ID` and `FRESHBOOKS_CLIENT_SECRET`
- Make sure there are no extra spaces or quotes

#### Can't find business_id
- The business_id might be in `response.business.business_id` or `response.business.account_id`
- Check the full API response to find the correct field

### Connection Issues

#### "FreshBooks access token not configured"
- Set `FRESHBOOKS_ACCESS_TOKEN` environment variable
- Or create a `FreshbooksToken` record in database

#### "FreshBooks business ID not configured"
- Set `FRESHBOOKS_BUSINESS_ID` environment variable
- Or ensure `FreshbooksToken` has `business_id` set

#### "Token expired"
- Tokens auto-refresh, but if refresh fails, run: `rails freshbooks:refresh_token`
- Or get new tokens using the OAuth flow

### Webhook Issues

#### Webhook not receiving events
- Verify webhook URL is accessible
- Check webhook secret matches
- Review FreshBooks webhook logs
- Ensure your server is publicly accessible (use ngrok for local development)

### Payment Link Issues

#### Payment link not working
- Verify `business_id` is correct
- Check invoice was created successfully
- Ensure invoice ID is valid
- Payment links format: `https://my.freshbooks.com/view/{business_id}/{invoice_id}`

### API Errors

#### General API errors
- Check FreshBooks API status
- Verify business_id is correct
- Review error response in logs
- Check rate limits (FreshBooks has API rate limits)

## Database Schema

### freshbooks_tokens
- `access_token` (text) - OAuth access token
- `refresh_token` (text) - OAuth refresh token
- `token_expires_at` (datetime) - Token expiration
- `business_id` (string) - FreshBooks business ID
- `user_freshbooks_id` (string) - FreshBooks user ID

### freshbooks_clients
- `freshbooks_id` (string, unique) - FreshBooks client ID
- `email`, `first_name`, `last_name`, `organization`, `phone`
- `address`, `city`, `province`, `postal_code`, `country`
- `raw_data` (jsonb) - Full FreshBooks response

### freshbooks_invoices
- `freshbooks_id` (string, unique) - FreshBooks invoice ID
- `freshbooks_client_id` (string) - Reference to client
- `invoice_id` (bigint) - Reference to local Invoice model
- `invoice_number`, `status`, `amount`, `amount_outstanding`
- `date`, `due_date`, `currency_code`, `notes`, `pdf_url`
- `raw_data` (jsonb) - Full FreshBooks response

### freshbooks_payments
- `freshbooks_id` (string, unique) - FreshBooks payment ID
- `freshbooks_invoice_id` (string) - Reference to invoice
- `amount`, `date`, `payment_method`, `currency_code`, `notes`
- `raw_data` (jsonb) - Full FreshBooks response

## Files Created

### Models
- `app/models/freshbooks_token.rb`
- `app/models/freshbooks_client.rb`
- `app/models/freshbooks_invoice.rb`
- `app/models/freshbooks_payment.rb`

### Services
- `app/services/freshbooks/base_client.rb`
- `app/services/freshbooks/clients.rb`
- `app/services/freshbooks/invoices.rb`
- `app/services/freshbooks/payments.rb`
- `app/services/freshbooks/invoice_creation_service.rb`

### Controllers
- `app/controllers/freshbooks_callback_controller.rb` (OAuth callback)
- `app/controllers/api/v1/freshbooks_controller.rb` (API endpoints)
- `app/controllers/api/v1/freshbooks_webhooks_controller.rb` (webhooks)

### Jobs
- `app/jobs/freshbooks/sync_clients_job.rb`
- `app/jobs/freshbooks/sync_invoices_job.rb`
- `app/jobs/freshbooks/sync_payments_job.rb`

### Migrations
- `db/migrate/20250101000001_create_freshbooks_tokens.rb`
- `db/migrate/20250101000002_create_freshbooks_clients.rb`
- `db/migrate/20250101000003_create_freshbooks_invoices.rb`
- `db/migrate/20250101000004_create_freshbooks_payments.rb`

## References

- [FreshBooks API Documentation](https://www.freshbooks.com/api/start)
- [FreshBooks OAuth Guide](https://www.freshbooks.com/api/authentication)
