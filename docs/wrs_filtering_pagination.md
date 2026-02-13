# Work Orders Filtering & Pagination

## Overview
The Work Orders API now supports comprehensive filtering and pagination using Ransack and Kaminari gems.

## Installation
After adding the gems to your Gemfile, run:
```bash
bundle install
```

## API Endpoints

### GET /api/v1/work_orders

#### Query Parameters

**Pagination:**
- `page` - Page number (default: 1)
- `per_page` - Items per page (default: 20, max: 100)

**Filtering (using Ransack syntax):**
- `q[created_at_gteq]` - Filter from date (created_at >=)
- `q[created_at_lteq]` - Filter to date (created_at <=)
- `q[total_vat_included_price_gteq]` - Minimum total price
- `q[total_vat_included_price_lteq]` - Maximum total price
- `q[grand_total_gteq]` - Minimum grand total
- `q[grand_total_lteq]` - Maximum grand total
- `q[status_eq]` - Filter by status (0=pending, 1=approved, 2=rejected, 3=completed)
- `q[name_cont]` - Search by name (contains)
- `q[address_cont]` - Search by address (contains)
- `q[reference_number_eq]` - Filter by reference number
- `q[user_name_cont]` - Search by user name
- `q[s]` - Sort by field (e.g., `created_at desc`, `grand_total asc`)

#### Example Requests

**Basic pagination:**
```
GET /api/v1/work_orders?page=2&per_page=10
```

**Date range filtering:**
```
GET /api/v1/work_orders?q[created_at_gteq]=2024-01-01&q[created_at_lteq]=2024-12-31
```

**Price range filtering:**
```
GET /api/v1/work_orders?q[grand_total_gteq]=1000&q[grand_total_lteq]=5000
```

**Status filtering:**
```
GET /api/v1/work_orders?q[status_eq]=1
```

**Search by name:**
```
GET /api/v1/work_orders?q[name_cont]=repair
```

**Combined filters with sorting:**
```
GET /api/v1/work_orders?q[created_at_gteq]=2024-01-01&q[status_eq]=1&q[s]=grand_total desc&page=1&per_page=20
```

#### Response Format

```json
{
  "data": [
    {
      "id": 1,
      "name": "Window Repair Service",
      "address": "123 Main St",
      "status": "approved",
      "grand_total": 2500.00,
      "created_at": "2024-01-15T10:30:00Z",
      "user": {
        "id": 1,
        "name": "John Doe",
        "email": "john@example.com"
      },
      "windows": [...]
    }
  ],
  "meta": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 100,
    "per_page": 20,
    "has_next_page": true,
    "has_prev_page": false
  }
}
```

## Available Filter Fields

### Direct Fields
- `name` - Work order name
- `slug` - Unique slug
- `flat_number` - Flat number
- `reference_number` - Reference number
- `address` - Address
- `details` - Details text
- `status` - Status (0=pending, 1=approved, 2=rejected, 3=completed)
- `created_at` - Creation date
- `updated_at` - Last update date
- `total_vat_included_price` - Total price including VAT
- `total_vat_excluded_price` - Total price excluding VAT
- `grand_total` - Grand total

### Association Fields
- `user_name` - User name
- `user_email` - User email
- `windows_location` - Window location
- `tools_name` - Tool name

## Ransack Predicates

Common predicates you can use:
- `_eq` - Equal
- `_not_eq` - Not equal
- `_cont` - Contains
- `_not_cont` - Does not contain
- `_start` - Starts with
- `_end` - Ends with
- `_gteq` - Greater than or equal
- `_lteq` - Less than or equal
- `_gt` - Greater than
- `_lt` - Less than
- `_in` - In array
- `_not_in` - Not in array

## Security Notes

- All filtering respects the existing Pundit authorization policies
- Only whitelisted attributes and associations are searchable
- Pagination is limited to maximum 100 items per page
- User can only see their own records unless they're an admin
