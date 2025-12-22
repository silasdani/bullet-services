# Service Object Standards

## Overview

This document defines standards for service objects in the Bullet Services application.

## Base Class

All service objects inherit from `ApplicationService`:

```ruby
class MyService < ApplicationService
  # Service implementation
end
```

## Interface Contract

### Required Methods

#### `call`
Every service must implement the `call` method:

```ruby
def call
  # Service logic here
  # Return self (for chaining) or result hash
  self
end
```

### Standard Methods (from ApplicationService)

- `success?` - Returns true if no errors
- `failure?` - Returns true if errors exist
- `add_error(message)` - Add an error message
- `add_errors(messages)` - Add multiple errors
- `errors` - Array of error messages
- `result` - Result object (set by service)

### Logging Methods

- `log_info(message)` - Log info level
- `log_error(message)` - Log error level
- `log_warn(message)` - Log warning level
- `log_debug(message)` - Log debug level

## Return Patterns

### Pattern 1: Self-Returning (Recommended)

Service returns itself, caller checks `success?`:

```ruby
class CreateInvoiceService < ApplicationService
  attribute :invoice_params
  attr_accessor :invoice

  def call
    @invoice = Invoice.new(invoice_params)
    if @invoice.save
      log_info "Invoice #{@invoice.id} created"
    else
      add_errors(@invoice.errors.full_messages)
    end
    self
  end
end

# Usage
service = CreateInvoiceService.new(invoice_params: params)
service.call
if service.success?
  render json: service.invoice
else
  render json: { errors: service.errors }, status: :unprocessable_entity
end
```

### Pattern 2: Result Hash

Service returns a hash with `:success` and data:

```ruby
def call
  invoice = Invoice.create(invoice_params)
  if invoice.persisted?
    { success: true, invoice: invoice }
  else
    add_errors(invoice.errors.full_messages)
    { success: false, errors: errors }
  end
end

# Usage
result = service.call
if result[:success]
  render json: result[:invoice]
else
  render json: { errors: result[:errors] }
end
```

### Pattern 3: Raise Exceptions (Use Sparingly)

For critical failures that should halt execution:

```ruby
def call
  raise ApplicationError, "Invalid input" if invalid?
  # ... processing ...
end
```

## Error Handling

### Using `with_error_handling`

Wrap operations that might fail:

```ruby
def call
  with_error_handling do
    perform_operation
  end
end
```

### Manual Error Handling

```ruby
def call
  begin
    perform_operation
  rescue StandardError => e
    log_error "Operation failed: #{e.message}"
    add_error(e.message)
  end
  self
end
```

## Transactions

### Using `with_transaction`

Wrap database operations in transactions:

```ruby
def call
  with_transaction do
    create_invoice
    create_freshbooks_invoice
    send_notification
  end
  self
rescue ActiveRecord::RecordInvalid => e
  add_error(e.message)
  self
end
```

### Explicit Transactions

```ruby
def call
  ActiveRecord::Base.transaction do
    # Multiple operations
  end
  self
end
```

## Attributes

Use `ActiveModel::Attributes` for typed attributes:

```ruby
class MyService < ApplicationService
  attribute :user_id, :integer
  attribute :invoice_params, :hash
  attribute :send_email, :boolean, default: true
end
```

## Examples

### Simple Service

```ruby
class SendEmailService < ApplicationService
  attribute :to, :string
  attribute :subject, :string
  attribute :body, :string

  def call
    return add_error('To address required') if to.blank?
    
    Mailer.deliver(to: to, subject: subject, body: body)
    log_info "Email sent to #{to}"
    self
  end
end
```

### Complex Service with Transactions

```ruby
class CreateInvoiceService < ApplicationService
  attribute :wrs_id, :integer
  attribute :client_data, :hash
  attr_accessor :invoice

  def call
    with_error_handling do
      with_transaction do
        ensure_freshbooks_client
        create_local_invoice
        create_freshbooks_invoice
        attach_pdf
        send_notification
      end
    end
    self
  end

  private

  def ensure_freshbooks_client
    @fb_client = FreshbooksClientEnsurer.new(client_data).call
    raise ApplicationError, "Failed to create client" unless @fb_client
  end

  def create_local_invoice
    @invoice = Invoice.create!(
      wrs_id: wrs_id,
      freshbooks_client_id: @fb_client['id']
    )
  end

  # ... other methods ...
end
```

## Best Practices

1. ✅ **Always return self** (for Pattern 1) or consistent hash (for Pattern 2)
2. ✅ **Use attributes** for typed parameters
3. ✅ **Log important operations**
4. ✅ **Use transactions** for multi-step database operations
5. ✅ **Handle errors gracefully** with `with_error_handling`
6. ✅ **Validate inputs** early in the `call` method
7. ✅ **Keep services focused** on a single responsibility
8. ✅ **Use descriptive names** that indicate the service's purpose
9. ✅ **Document complex logic** with comments
10. ✅ **Test services thoroughly** with unit tests

## Anti-Patterns

### ❌ Don't Mix Return Patterns

```ruby
# Bad - inconsistent returns
def call
  return { success: true } if condition
  self
end
```

### ❌ Don't Swallow Errors

```ruby
# Bad - hides errors
def call
  begin
    risky_operation
  rescue
    # Silent failure
  end
end

# Good - logs and reports errors
def call
  with_error_handling do
    risky_operation
  end
end
```

### ❌ Don't Skip Transactions for Multi-Step Operations

```ruby
# Bad - no transaction
def call
  create_invoice
  create_freshbooks_invoice
  send_email
end

# Good - wrapped in transaction
def call
  with_transaction do
    create_invoice
    create_freshbooks_invoice
    send_email
  end
end
```

## Migration Guide

### Converting Existing Services

1. **Inherit from ApplicationService**
2. **Use attributes** instead of instance variables
3. **Return self** consistently
4. **Add error handling** with `with_error_handling`
5. **Wrap transactions** with `with_transaction`
6. **Add logging** for important operations

### Example Migration

```ruby
# Before
class OldService
  def initialize(params)
    @params = params
  end

  def call
    result = do_something
    { success: true, data: result }
  end
end

# After
class NewService < ApplicationService
  attribute :params, :hash

  def call
    result = do_something
    @result = result
    log_info "Operation completed"
    self
  end
end
```
