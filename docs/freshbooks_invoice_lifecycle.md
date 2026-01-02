# FreshBooks Invoice Lifecycle - Bulletproof Implementation

This document describes the bulletproof lifecycle management system for FreshBooks invoices.

## Overview

The invoice lifecycle system ensures that:
1. **Invoice status** stays synchronized between FreshBooks and local database
2. **Payments** automatically reconcile invoice status and outstanding amounts
3. **Webhooks** trigger full syncs instead of partial updates
4. **Data consistency** is maintained across all related records
5. **Error recovery** handles failures gracefully with retries and logging

## Core Components

### 1. InvoiceLifecycleService

Central service (`app/services/freshbooks/invoice_lifecycle_service.rb`) that handles:
- **Sync from FreshBooks**: Fetches latest invoice data and updates local records
- **Payment Reconciliation**: Calculates invoice status based on payments
- **Status Propagation**: Updates related Invoice model when FreshbooksInvoice status changes
- **Verification**: Checks if invoice is in sync with FreshBooks

### 2. Enhanced Model Callbacks

`FreshbooksInvoice` model now includes:
- **after_update**: Propagates status changes to Invoice model
- **after_update**: Reconciles payments when outstanding amount changes
- **after_create**: Triggers async sync when new invoice is created

### 3. Improved Sync Jobs

#### SyncInvoicesJob
- Better error handling (continues on individual failures)
- Uses lifecycle service for full reconciliation
- Logs errors without stopping entire sync

#### SyncPaymentsJob
- Automatically reconciles invoice status after syncing payments
- Calculates outstanding amounts from payments
- Updates invoice status based on payment totals

### 4. Enhanced Webhook Handling

Webhooks now:
- Use lifecycle service for bulletproof updates
- Trigger full invoice syncs instead of partial updates
- Handle errors gracefully with proper logging

## Lifecycle Flow

### Invoice Creation
1. Invoice created in FreshBooks via `InvoiceCreationService`
2. `InvoiceRecordSyncer` creates/updates `FreshbooksInvoice` record
3. Lifecycle service propagates status to `Invoice` model
4. `after_create` callback triggers async sync for verification

### Payment Received
1. Payment webhook received
2. Lifecycle service handles payment:
   - Creates/updates payment record
   - Reconciles invoice status from payments
   - Updates outstanding amount
   - Propagates status to Invoice model
3. Full invoice sync triggered to ensure consistency

### Status Updates
1. Invoice status changes in FreshBooks (via webhook or manual update)
2. Lifecycle service syncs from FreshBooks
3. Status propagated to Invoice model
4. Payments reconciled if needed

### Periodic Sync
1. `SyncInvoicesJob` runs (manually or scheduled)
2. Fetches all invoices from FreshBooks
3. Updates local records using lifecycle service
4. Reconciles payments for each invoice
5. Propagates status changes

## Usage

### Manual Reconciliation

```ruby
# Reconcile a specific invoice
fb_invoice = FreshbooksInvoice.find_by(freshbooks_id: '12345')
lifecycle_service = Freshbooks::InvoiceLifecycleService.new(fb_invoice)
lifecycle_service.sync_from_freshbooks
lifecycle_service.reconcile_payments
```

### Verify Sync Status

```ruby
fb_invoice = FreshbooksInvoice.find_by(freshbooks_id: '12345')
result = fb_invoice.verify_sync
# => { synced: true/false, errors: [...] }
```

### Rake Tasks

```bash
# Verify all invoices are in sync
rake freshbooks:invoices:verify_sync

# Reconcile all invoices
rake freshbooks:invoices:reconcile_all

# Reconcile specific invoice
rake freshbooks:invoices:reconcile[FRESHBOOKS_ID]
```

## Status System

Both `Invoice` and `FreshbooksInvoice` models now use the **same status values** through the `InvoiceStatus` concern:

### Valid Statuses
- `draft` - Invoice is in draft state
- `sent` - Invoice has been sent to client
- `viewed` - Invoice has been viewed by client
- `paid` - Invoice has been fully paid
- `void` / `voided` - Invoice has been voided (normalized to `voided`)

### Status Synchronization
- **FreshbooksInvoice → Invoice**: Status automatically propagates when FreshbooksInvoice status changes
- **Invoice → FreshbooksInvoice**: When Invoice has FreshbooksInvoice, status syncs on update
- **Normalization**: Status values are automatically normalized (e.g., `void` → `voided`)
- **Validation**: Both models validate status against the same set of valid values

## Payment Reconciliation Logic

Invoice status is determined by:
1. If outstanding amount ≤ 0 and invoice amount > 0 → `paid`
2. If total paid > 0 and outstanding > 0 → `sent` (partially paid)
3. If total paid == 0 → uses current status or `sent`
4. Void status is preserved

## Error Handling

- All operations wrapped in transactions
- Individual failures don't stop batch operations
- Errors logged with full context
- Retry logic in jobs (exponential backoff)
- Verification can detect and report discrepancies

## Data Consistency Guarantees

1. **Transaction Safety**: All updates wrapped in transactions
2. **Idempotency**: Operations can be safely retried
3. **Verification**: Can detect and report sync issues
4. **Automatic Reconciliation**: Payments automatically update invoice status
5. **Status Propagation**: Changes propagate to related models

## Monitoring

Check logs for:
- `InvoiceLifecycleService` sync operations
- Payment reconciliation results
- Webhook processing
- Sync job errors

Use rake tasks to verify sync status and reconcile any discrepancies.

