# /plan-status - View All Plans

Display the status of all implementation plans.

> **Script:** `./scripts/plan-status.sh` — invoke directly for zero-token execution.

## Workflow

1. **Retrieve Plans**

   ```bash
   ./scripts/plan-index.sh list
   ```

2. **Format Output**
   Display plans grouped by status:

   ```
   ## In Progress
   - [ID] Title (created: date)

   ## Planned
   - [ID] Title (created: date)

   ## Done
   - [ID] Title (completed: date)

   ## Unplanned (Implemented without plan)
   - [ID] Title (result: path/to/result.md)
   ```

3. **Summary Statistics**
   - Total plans
   - By status count
   - Recent activity

## Example Output

```
Plan Status Summary
==================

In Progress (1):
  [abc123] Add user authentication
    Created: 2026-02-05
    File: plans/2026-02-05-add-user-authentication.md

Planned (2):
  [def456] Implement dashboard widgets
  [ghi789] Add export functionality

Done (3):
  [jkl012] Setup project structure (completed: 2026-02-01)

Unplanned (1):
  [mno345] Quick bugfix for login
    Result: plans/results/2026-02-04-quick-bugfix-login.md

---
Total: 7 plans | Planned: 2 | In Progress: 1 | Done: 3 | Unplanned: 1
```
