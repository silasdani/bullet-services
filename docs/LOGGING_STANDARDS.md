# Logging Standards

## Overview

This document defines logging standards and best practices for the Bullet Services application.

## Log Levels

### DEBUG
Use for detailed diagnostic information, typically only of interest when diagnosing problems.

```ruby
Rails.logger.debug "Processing invoice #{invoice.id} with #{invoice.lines.count} line items"
```

**When to use:**
- Detailed execution flow
- Variable values during debugging
- Step-by-step process tracking

### INFO
Use for general informational messages about application flow.

```ruby
Rails.logger.info "Invoice #{invoice.id} created successfully for client #{client.email}"
```

**When to use:**
- Successful operations
- Important state changes
- Business events
- User actions (non-sensitive)

### WARN
Use for potentially harmful situations that don't prevent the application from functioning.

```ruby
Rails.logger.warn "Rate limit approaching for IP #{request.remote_ip}: #{current_count}/#{limit}"
```

**When to use:**
- Recoverable errors
- Deprecated feature usage
- Performance concerns
- External service degradation

### ERROR
Use for error events that might still allow the application to continue running.

```ruby
Rails.logger.error "Failed to process WRS #{wrs.id}: #{error.message}"
Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
```

**When to use:**
- Failed operations
- Exception handling
- External service failures
- Data validation failures

### FATAL
Use for very severe error events that might cause the application to abort.

```ruby
Rails.logger.fatal "Database connection lost: #{error.message}"
```

**When to use:**
- Critical system failures
- Data corruption risks
- Security breaches

## Logging Format

### Standard Format

```ruby
Rails.logger.info "[#{self.class.name}] Action: #{action_name} | User: #{user.id} | Result: #{result}"
```

### Structured Logging (Recommended)

```ruby
Rails.logger.info({
  event: 'invoice_created',
  invoice_id: invoice.id,
  client_id: invoice.client_id,
  amount: invoice.total_amount,
  user_id: current_user.id
}.to_json)
```

## Context Information

Always include relevant context:

```ruby
# Good
Rails.logger.error "Failed to process payment for invoice #{invoice.id}: #{error.message}"

# Bad
Rails.logger.error "Payment failed"
```

### Common Context Fields

- **User ID**: `user_id: current_user.id`
- **Resource ID**: `invoice_id: invoice.id`
- **Request ID**: `request_id: request.uuid`
- **IP Address**: `ip: request.remote_ip` (for security events)
- **Action**: `action: 'create_invoice'`
- **Duration**: `duration_ms: elapsed_time`

## Service Object Logging

### Using ApplicationService Logger

```ruby
class MyService < ApplicationService
  def call
    log_info "Starting process for user #{user.id}"
    
    # ... processing ...
    
    if success?
      log_info "Process completed successfully"
    else
      log_error "Process failed: #{errors.join(', ')}"
    end
  end
end
```

### Logging Patterns

```ruby
# Start of operation
log_info "Starting #{operation_name} for #{resource_type} #{resource_id}"

# Progress updates
log_info "Processing step #{step_number}/#{total_steps}"

# Success
log_info "#{operation_name} completed successfully"

# Failure
log_error "#{operation_name} failed: #{error_message}"
log_error "Context: #{context_hash.to_json}" if detailed_context?
```

## Security Considerations

### Never Log Sensitive Data

**DO NOT LOG:**
- Passwords or password hashes
- Credit card numbers
- API tokens or secrets
- Personal identification numbers (SSN, etc.)
- Full authentication tokens

**DO LOG:**
- User IDs (not emails in some contexts)
- Resource IDs
- Action types
- Error messages (sanitized)
- Timestamps

### Example

```ruby
# Bad
Rails.logger.info "User #{user.email} logged in with password #{password}"

# Good
Rails.logger.info "User #{user.id} logged in successfully from #{request.remote_ip}"
```

## Performance Logging

### Slow Query Logging

```ruby
start_time = Time.current
# ... operation ...
elapsed = ((Time.current - start_time) * 1000).round(2)

if elapsed > 1000 # Log if slower than 1 second
  Rails.logger.warn "Slow operation detected: #{operation_name} took #{elapsed}ms"
end
```

### Request Duration

```ruby
# In ApplicationController
around_action :log_request_duration

def log_request_duration
  start_time = Time.current
  yield
  duration = ((Time.current - start_time) * 1000).round(2)
  Rails.logger.info "Request #{request.path} completed in #{duration}ms"
end
```

## External Service Logging

### API Calls

```ruby
Rails.logger.info "Calling FreshBooks API: #{endpoint}"
response = make_api_call
Rails.logger.info "FreshBooks API response: #{response.code} (#{response_time}ms)"
```

### Error Handling

```ruby
begin
  result = external_service.call
rescue ExternalServiceError => e
  Rails.logger.error "External service error: #{e.class.name}"
  Rails.logger.error "Endpoint: #{endpoint}"
  Rails.logger.error "Status: #{e.status_code}" if e.respond_to?(:status_code)
  Rails.logger.error "Message: #{e.message}"
  raise
end
```

## Background Job Logging

### Job Start/End

```ruby
class MyJob < ApplicationJob
  def perform(resource_id)
    Rails.logger.info "[#{self.class.name}] Starting job for resource #{resource_id}"
    
    # ... processing ...
    
    Rails.logger.info "[#{self.class.name}] Job completed successfully"
  rescue StandardError => e
    Rails.logger.error "[#{self.class.name}] Job failed: #{e.message}"
    raise
  end
end
```

## Log Aggregation

### Structured Logs for Aggregation

Use JSON format for better log aggregation:

```ruby
Rails.logger.info({
  timestamp: Time.current.iso8601,
  level: 'info',
  service: 'bullet-services',
  event: 'invoice_created',
  invoice_id: invoice.id,
  user_id: current_user.id,
  duration_ms: elapsed_time
}.to_json)
```

## Environment-Specific Logging

### Development

```ruby
if Rails.env.development?
  Rails.logger.debug "Detailed debug info: #{debug_data.inspect}"
end
```

### Production

```ruby
# Only log essential information
Rails.logger.info "Invoice #{invoice.id} created"
# Don't log full objects or sensitive data
```

## Log Rotation

Configure log rotation in `config/environments/production.rb`:

```ruby
config.logger = ActiveSupport::Logger.new(
  Rails.root.join('log', 'production.log'),
  5, # Keep 5 log files
  100.megabytes # 100MB per file
)
```

## Monitoring and Alerts

### Key Metrics to Monitor

1. **Error Rate**: Count of ERROR and FATAL logs
2. **Response Times**: Duration logged for requests
3. **External Service Failures**: Errors from external APIs
4. **Authentication Failures**: Failed login attempts
5. **Rate Limit Hits**: Throttled requests

### Alert Thresholds

- **ERROR logs > 10/minute**: Investigate immediately
- **FATAL logs**: Alert immediately
- **Response time > 2 seconds**: Performance concern
- **External service failures**: Alert if > 5% failure rate

## Best Practices Summary

1. ✅ **Use appropriate log levels**
2. ✅ **Include relevant context**
3. ✅ **Never log sensitive data**
4. ✅ **Use structured logging for aggregation**
5. ✅ **Log at service boundaries**
6. ✅ **Log errors with full context**
7. ✅ **Use consistent format**
8. ✅ **Monitor and alert on errors**
9. ✅ **Rotate logs regularly**
10. ✅ **Review logs regularly for issues**

## Examples

### Good Logging Examples

```ruby
# Service operation
log_info "Creating invoice for WRS #{wrs.id}"
log_info "Invoice #{invoice.id} created successfully"

# Error handling
log_error "Failed to process WRS: #{error.class} - #{error.message}"
log_error "WRS ID: #{wrs.id}"

# Performance
log_warn "Slow query detected: #{query_time}ms for #{query_name}"
```

### Bad Logging Examples

```ruby
# Too vague
log_error "Error occurred"

# Missing context
log_info "Invoice created"

# Sensitive data
log_info "User password: #{password}"

# Too verbose in production
log_debug large_object.inspect
```
