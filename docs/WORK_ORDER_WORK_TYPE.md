# Work Order `work_type` Usage

Work orders support two types: **WRS** (window schedule repair) and **general** work.

## Model Usage

```ruby
# Scopes
WorkOrder.wrs_only        # Only WRS records
WorkOrder.general_only      # Only general work records

# Create WRS (default)
wrs = WorkOrder.create!(
  name: "Flat 3 Window Repair",
  building_id: 1,
  user_id: 1,
  work_type: :wrs,  # optional – default
  # ... windows, etc.
)

# Create general work
general = WorkOrder.create!(
  name: "Plumbing Repair",
  building_id: 1,
  user_id: 1,
  work_type: :general,
  # ... no windows required for general
)

# Check type
wrs.wrs?      # => true
wrs.general?  # => false
general.general?  # => true
```

## API Usage

### Create

**WRS (default):**
```json
POST /api/v1/work_orders
{
  "work_order": {
    "name": "Flat 3 Window Repair",
    "building_id": 1,
    "flat_number": "3",
    "details": "Broken sash",
    "work_type": "wrs",
    "windows_attributes": {
      "0": { "location": "Living room", "tools_attributes": { "0": { "name": "Seal", "price": 25 } } }
    }
  }
}
```

**General work:**
```json
POST /api/v1/work_orders
{
  "work_order": {
    "name": "Plumbing Repair",
    "building_id": 1,
    "details": "Leak in bathroom",
    "work_type": "general"
  }
}
```

If `work_type` is omitted on create, it defaults to `wrs`.

### Update

```json
PATCH /api/v1/work_orders/:id
{
  "work_order": {
    "work_type": "general"
  }
}
```

### Index (filter by type)

```
GET /api/v1/work_orders?work_type=wrs
GET /api/v1/work_orders?work_type=general
```

### Response

`work_type` is included in the serialized payload:

```json
{
  "data": {
    "id": 1,
    "name": "Flat 3 Window Repair",
    "work_type": "wrs",
    "status": "pending",
    ...
  }
}
```

## Avo Admin

- Filter by `work_type` on the index
- Set `work_type` on create/edit forms
- Values: `wrs` | `general`
