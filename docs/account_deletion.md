# Account Deletion

## Overview

User accounts are **soft-deleted** when a user (or admin) requests deletion. They are **permanently removed** only after a 30-day grace period.

## Flow

1. **Request deletion**  
   - **API**: `DELETE /api/v1/users/:id` (user can delete their own account; admins can delete any user).  
   - **Devise registrations**: `DELETE /auth` is disabled (`head :method_not_allowed`); use the API above.

2. **Soft delete**  
   - The user record is not removed.  
   - `deleted_at` is set to the current time.  
   - The user is excluded from normal queries (default scope) and cannot sign in.

3. **Grace period (30 days)**  
   - The account remains in the database for 30 days.  
   - During this time it can be restored (e.g. via Rails Admin or `User.unscoped.find(id).restore!`).

4. **Permanent deletion**  
   - A recurring job runs daily (when using Solid Queue with `ACTIVE_JOB_ADAPTER=solid_queue`).  
   - It finds users where `deleted_at < 30.days.ago` and calls `destroy` on each.  
   - Those rows are permanently removed from the database.  
   - If a user has associations that prevent deletion (e.g. `window_schedule_repairs` with `dependent: :restrict_with_error`), that user is skipped and a warning is logged.

## Configuration

- **Grace period**: `User::PERMANENT_DELETION_GRACE_DAYS` (default: 30).  
- **Recurring job**: `CleanupDeletedUsersJob`, scheduled in `config/recurring.yml` (e.g. 2am daily in production when using Solid Queue).

## Manual run

To run the cleanup once (e.g. in console or via cron):

```ruby
CleanupDeletedUsersJob.perform_now
```

Or via rake (if you add a task):

```bash
rails runner "CleanupDeletedUsersJob.perform_now"
```

## Restore before permanent deletion

To restore a soft-deleted user within the 30-day window:

```ruby
user = User.unscoped.find(id)
user.restore!
```
