# /check-guardrails - Review Changes Against Guardrails

Review staged or recent changes against all instant failure rules and golden rules, reporting violations and warnings.

> **Script:** `./scripts/guardrails-check.sh` — invoke directly for zero-token execution.

## Arguments

- `<scope>` (optional): What to check. Defaults to staged changes.
  - `staged` — Check staged changes (default)
  - `unstaged` — Check unstaged changes
  - `branch` — Check all changes on the current branch vs main

## Workflow

1. **Run gather script:**

   ```bash
   ./scripts/guardrails-gather.sh <scope>
   ```

   This produces a JSON object with:
   - `scope` — what was checked (staged/unstaged/branch)
   - `changedFiles` — array of `{path, diff, layer}` for each changed file, where layer is the Clean Architecture classification (domain/domain-port/application/interfaces/infrastructure/ui/test/config/script)
   - `potentialViolations` — array of `{rule, file, line, snippet}` for pattern-matched IF rules (IF-01 framework in domain, IF-02 SQL concat, IF-06 mutable events, IF-14 hardcoded secrets, IF-15 missing API prefix)
   - `guardrailsContent` — full text of `.claude/guardrails.md`

2. **Verify script-detected violations**

   For each entry in `potentialViolations`, review the context to filter false positives:
   - IF-02: Is the string concatenation actually building a query, or just a coincidental keyword?
   - IF-14: Is it a test fixture, environment variable name, or actual hardcoded secret?
   - IF-15: Is the route intentionally public (health check, docs)?

3. **Check rules the script cannot pattern-match**

   Using `changedFiles` diffs and layers, evaluate these rules that require semantic understanding:

   | Rule | What to Look For |
   |------|-----------------|
   | IF-04: Internal data leakage | Domain entities returned directly from controllers without explicit contract justification |
   | IF-07: Logic outside domain | Business rules in controllers, config, or adapter files (check files with layer != domain) |
   | IF-11: Partial field sync | New field added to one representation (entity, DTO, DB) without matching updates in others |
   | IF-12: Untested changes | Changed production files without corresponding test file changes |
   | IF-13: Duplicated logic | Similar code blocks appearing in different files within the diff |

4. **Check golden rule compliance**

   Review changes for alignment with golden rules — these produce warnings, not violations:

   - Immutability patterns followed
   - Proper Clean Architecture dependency direction (inward only — use `layer` field to verify)
   - Request/response mapping instead of entity exposure
   - Defense-in-depth validation present
   - Appropriate test coverage by circle
   - Cause + Effect event model followed

5. **Generate report**

   ```
   ## Guardrail Check Report

   Scope: {scope}
   Files checked: {count}

   ### Violations (Must Fix)

   - **IF-XX: {Rule}** in `path/to/file.ext`:{line}
     {Description of the violation}

   ### Warnings (Should Review)

   - **Golden Rule {N}: {Rule}** in `path/to/file.ext`
     {Description of the concern}

   ### Passed

   {count} instant failure rules checked — {pass_count} passed, {violation_count} violated
   {count} golden rules checked — {pass_count} aligned, {warning_count} warnings

   ### Summary

   {PASS | FAIL}: {summary message}
   ```

6. **Exit with status**

   - If any instant failure violations exist: report as FAIL
   - If only warnings: report as PASS WITH WARNINGS
   - If clean: report as PASS

## Rules

- Instant failure violations are blocking — they must be fixed before committing
- Golden rule warnings are advisory — use judgment on whether to address them
- Check the full diff context, not just added lines — removals can also introduce violations
- Cross-reference IF-11 (partial field sync) by checking if all representations are updated when a field is added
- For IF-12 (untested changes), check if changed production files have corresponding test file changes
