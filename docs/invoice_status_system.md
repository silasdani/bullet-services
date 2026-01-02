# Invoice Status System

## Overview

Both `Invoice` and `FreshbooksInvoice` models now use the **same status values** through the `InvoiceStatus` concern, ensuring consistency across the application.

## Valid Status Values

The following statuses are valid for both models:

- `draft` - Invoice is in draft state
- `sent` - Invoice has been sent to client
- `viewed` - Invoice has been viewed by client
- `paid` - Invoice has been fully paid
- `void` / `voided` - Invoice has been voided (automatically normalized to `voided`)

## Status Normalization

Status values are automatically normalized:
- `void` → `voided` (standardized)
- Case-insensitive matching
- Whitespace trimming
- Variations like "voided + email sent" → `voided`

## Status Synchronization

### FreshbooksInvoice → Invoice
When a `FreshbooksInvoice` status changes:
1. `after_update` callback triggers `propagate_status_to_invoice`
2. Status is mapped and normalized
3. `Invoice` model's `status` and `final_status` are updated

### Invoice → FreshbooksInvoice
When an `Invoice` is updated and has associated `FreshbooksInvoice`:
1. `after_update` callback checks if sync is needed
2. Compares current status with `FreshbooksInvoice` status
3. Updates `Invoice` status if they differ

### Loop Prevention
- Callbacks check if status was just updated to prevent infinite loops
- Uses `update_columns` to skip callbacks when needed
- Only syncs when status actually differs

## Model Methods

### Shared Methods (from InvoiceStatus concern)
Both models have:
- `draft?`, `sent?`, `viewed?`, `paid?`, `void?`, `voided?`, `unpaid?`, `active?`
- `can_transition_to?(new_status)` - Check if status transition is valid
- `canonical_status` - Get normalized status

### Scopes
Both models have:
- `draft`, `sent`, `viewed`, `paid`, `voided` - Status scopes
- `unpaid` - Not paid, void, or voided
- `active` - Not voided (Invoice also checks `is_archived`)

## Status Transitions

Valid status transitions:

```
draft → sent, void, voided
sent → viewed, paid, void, voided
viewed → paid, void, voided
paid → (final, no transitions)
void → (final, no transitions)
voided → (final, no transitions)
```

## Validation

Both models validate status against `VALID_STATUSES`:
- Invalid statuses raise validation errors
- Status is normalized before validation
- `nil` status is allowed (but not recommended)

## Usage Examples

### Check Status
```ruby
invoice.draft?      # => true/false
invoice.paid?       # => true/false
invoice.voided?     # => true/false
```

### Query by Status
```ruby
Invoice.draft       # All draft invoices
Invoice.paid        # All paid invoices
Invoice.unpaid      # All unpaid invoices
Invoice.active      # All active (not voided) invoices
```

### Status Transition
```ruby
invoice.can_transition_to?('paid')  # => true/false
```

### Get Normalized Status
```ruby
invoice.canonical_status  # => 'voided' (normalized from 'void')
```

## Integration with FreshBooks

When syncing from FreshBooks:
1. FreshBooks numeric status codes are converted to strings
2. Status is normalized using `InvoiceStatusConverter`
3. Both `FreshbooksInvoice` and `Invoice` are updated
4. Status values remain consistent across both models

## Best Practices

1. **Always use normalized statuses** - Let the concern handle normalization
2. **Check transitions** - Use `can_transition_to?` before changing status
3. **Sync when needed** - Status syncs automatically, but can be triggered manually
4. **Validate status** - The concern validates status values automatically
5. **Use scopes** - Use model scopes for querying by status

