# /complete-plan - Mark Plan as Done

Mark an implementation plan as completed.

> **Script:** `./scripts/complete-plan.sh` — invoke directly for zero-token execution.

## Arguments

- `<plan-id>` or `<title>`: Plan ID (UUID) or partial title to find the plan

## Workflow

1. **Find Plan**
   If argument looks like a UUID, use directly. Otherwise search by title:

   ```bash
   ./scripts/plan-index.sh find "<title>"
   ```

2. **Verify Plan Exists**
   Ensure the plan is found and is in `in_progress` or `planned` status.

3. **Update Status**

   ```bash
   ./scripts/plan-index.sh update-status "<id>" "done"
   ```

4. **Confirmation**
   Display completion message with plan details.

## Example

```
/complete-plan abc123
```

Or by title:

```
/complete-plan user authentication
```

Output:

```
Plan completed: Add user authentication
  ID: abc123
  File: plans/2026-02-05-add-user-authentication.md
  Completed at: 2026-02-05T14:30:00Z
```

## Notes

- Plans should only be marked done after all quality gates pass
- The `completedAt` timestamp is automatically set
- Use `/plan-status` to verify the update
