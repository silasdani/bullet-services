# Supervisor Role

Supervisors (3 users) have the following permissions:

## Capabilities

1. **Create work orders without prices (notification)**
   - Can create work orders with tools (tool names only; prices are stored as 0)
   - Admin receives a notification: "Work order created by supervisor (needs pricing)"

2. **Tools only, no prices**
   - Can add/edit tools (name only)
   - Cannot see: `total_vat_included_price`, `total_vat_excluded_price`, `total`, tool `price`, window `total_price`

3. **Adjust only work orders they created**
   - Can update/delete only work orders where `user_id = supervisor.id`
   - Can have multiple work orders at the same flat (different windows)

4. **See all projects**
   - Building index: sees all buildings (like admin)

5. **All work orders from assigned project**
   - When assigned to a work order on building B, sees all work orders for building B
   - Can access building work order list if: created work order on that building **or** assigned to any work order on that building

## Policy Summary

| Resource | index? | show? | create? | update? | destroy? |
|----------|--------|-------|---------|--------|----------|
| Building | ✓ | ✓ | ✓ | ✓ | ✗ |
| WorkOrder | ✓ | Own + assigned | ✓ | Own only | ✗ |
| Window | ✓ | Own work orders only | ✓ | Own work orders only | Own work orders only |

## API

- Serializers hide prices for `scope.supervisor?`
- CreationService: tools get `price: 0` when `user.supervisor?`; notifies admin on create
- UpdateService: tools get `price: 0` when `current_user.supervisor?`

## Assigning a supervisor to a project

Use work order assignment: assign the supervisor to any work order on a building. They will then see all work orders for that building.

## Seeds

Run `rails db:seed` to add the Supervisor status definition for Avo badge display.
