# /plan - Create Implementation Plan

Create a structured implementation plan for a feature before coding.

> **Script:** `./scripts/plan-init.sh` — invoke directly for zero-token execution.

## Arguments

- `<feature-name>`: Short descriptive name for the feature

## Workflow

1. **Generate Filename**

   ```
   plans/YYYY-MM-DD-<slug>.md
   ```

   Where `<slug>` is the feature name converted to lowercase with spaces replaced by hyphens.

2. **Create Plan Document**
   Create the plan file with this template:

   ```markdown
   # <Feature Name>

   ## Summary

   Brief description of what this feature accomplishes.

   ## Requirements

   - [ ] Requirement 1
   - [ ] Requirement 2

   ## Implementation Steps

   1. Step 1
   2. Step 2

   ## Files to Modify/Create

   - `path/to/file` - Description of changes

   ## Testing Strategy

   - Unit tests: ...
   - Acceptance tests: ...

   ## Quality Gates

   - [ ] Unit tests pass
   - [ ] Lint passes
   - [ ] Format check passes
   - [ ] Acceptance tests pass (if applicable)
   ```

3. **Register in Index**

   ```bash
   ./scripts/plan-index.sh add "<Feature Name>" "plans/YYYY-MM-DD-<slug>.md" "planned"
   ```

4. **Output**
   Display the plan file path and ID for reference.

5. **Next step reminder**
   Display: "Run `/assess-readiness <plan-id>` to evaluate complexity before implementation."

## Example

```
/plan Add user authentication
```

Creates `plans/2026-02-05-add-user-authentication.md` and registers it in the index.
