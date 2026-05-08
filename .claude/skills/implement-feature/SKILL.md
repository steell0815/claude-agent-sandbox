# /implement-feature - TDD Feature Implementation

Implement the requested feature following CLAUDE.md and project conventions.

## Plan Integration

Before starting implementation, check for an existing plan:

1. **Check for Existing Plan**

   ```bash
   ./scripts/plan-index.sh find "<feature-name>"
   ```

2. **If Plan Found**
   - Update status to `in_progress`:
     ```bash
     ./scripts/plan-index.sh update-status "<plan-id>" "in_progress"
     ```
   - Read the plan file for requirements and steps
   - **Check for readiness assessment:**
     - Look for `## Implementation Readiness Assessment` in the plan file
     - If **missing**: warn "No readiness assessment found. Run `/assess-readiness <plan-id>` first, or proceed at your own risk."
     - If **present and band is ORANGE or RED**: block implementation and instruct: "This plan is rated {BAND}. Decompose into sub-features before implementing. Run `/assess-readiness` on each sub-plan."
     - If **present with preparation tasks**: display the preparation checklist as a reminder before proceeding
   - Follow the documented implementation steps

3. **If No Plan Found**
   - Create a result document: `plans/results/YYYY-MM-DD-<slug>.md`
   - Register as unplanned:
     ```bash
     ./scripts/plan-index.sh add "<feature-name>" "" "unplanned" "plans/results/YYYY-MM-DD-<slug>.md"
     ```
   - Document decisions and changes made in the result file

4. **On Completion**
   - Update plan status to `done`:
     ```bash
     ./scripts/plan-index.sh update-status "<plan-id>" "done"
     ```

## Workflow

1. **Explore**: Use Explore agent to understand relevant codebase areas
2. **Plan**: Identify files to modify, interfaces to extend, tests to add
3. **TDD**: Follow Test-Driven Development approach, for each new piece of functionality:
   - Write a failing test
   - Implement minimal code to make it pass
   - Refactor if necessary, ensuring all tests still pass
   > TDD is crucial to maintain code quality, ensure test coverage, and drive design decisions based on testability.
3. **Unit Testing**: Units are tested in isolation. A unit is defined by the behavioral bounds of a component. A unit may internally be composed of multiple files, but tests should focus on the public interface and behavior of the component as a whole, rather than internal implementation details. This promotes better encapsulation and allows for refactoring without breaking tests.
4. **Implement**: Implementation goes along the TDD cycle, ensuring that all new code is covered by tests and adheres to project conventions (no comments, small functions, etc.)
5. **Acceptance Test**: Ask for acceptance test, if not supplied for acceptance criteria, create one based on the criteria and have it reviewed by the requester. This ensures that the feature meets the defined requirements and provides a clear validation of functionality from the user's perspective.
6. **Quality Gates**: Run all quality gate checks (see "Definition of Deployable" in CONTRIBUTING.md)
7. **OpenApi Spec**: If the feature involves changes to the API, update the OpenAPI specification accordingly, ensuring that it accurately reflects the new endpoints, request/response formats, and any changes to existing API behavior.
8. **Documentation**: Update documentation if necessary, ensuring it reflects the new feature and any changes made to existing functionality. Documentation should be clear, concise, and focused on the user-facing aspects of the feature, rather than internal implementation details. In case public API is involved, reference the relevant OpenAPI spec sections in the documentation.

## 4-Agent Orchestration

For plan-based work, use the 4-agent pattern defined in CLAUDE.md. The Orchestrator (main thread) coordinates the agents per phase.

### Agent Launch Rules

**Implementor** — runs in a worktree (`isolation: "worktree"`). Prompt must include: plan phase context, constraints from CLAUDE.md, verification command.

**Chronologist** — launched after Implementor completes. Prompt must include:
- The plan file path to write to
- The worktree path to inspect (git log, git diff)
- Explicit instruction: **"Append to `## Implementation Log` in the plan file using Edit/Write tools. Do NOT return text — write directly."**
- The phase log format from CLAUDE.md

**Verifier** — launched after Chronologist (or in parallel). Prompt must include the worktree path and this checklist:
1. Build passes
2. Tests pass (count reported)
3. Guardrails compliance (relevant IF rules)
4. Code quality (project conventions)
5. **Implementation Log entry exists** for this phase in the plan file

**Attestation:** Before completing, the Verifier must create `.claude/cache/verifier-attestation-{plan-id}.json` with:
```json
{
  "plan_id": "<uuid>",
  "phase": "<phase name>",
  "timestamp": "<ISO 8601>",
  "build_passed": true,
  "tests_passed": true,
  "guardrails_clean": true,
  "coverage_met": true,
  "log_updated": true,
  "commit_sha": "<sha>"
}
```

If the Verifier reports that the Implementation Log entry is missing, the Orchestrator must launch the Chronologist again before proceeding.

### JIRA Sync After Each Phase

After the Verifier passes, the Orchestrator pushes the updated epic description to JIRA via `~/.claude/scripts/jira-update-description.sh`. The ADF document must include the **Implementation Log** section with all completed phases. Use the same ADF visual conventions as `/assess-readiness` (status lozenges, band circles, bar chart) plus:

- An `## Implementation Log` heading
- Each completed phase as a sub-section with files, test counts, key decisions
- Use ADF `codeBlock` for file lists, `status` lozenges for phase status (`COMPLETE` = green)

This ensures JIRA always reflects the latest implementation progress — not just the assessment, but the actual work done.

### Mid-Flight Unplanned Fixes

During plan-based orchestration, issues may arise that require fixes outside the plan scope (e.g., CI failures, missing `.gitignore` entries, coverage threshold adjustments). These fixes bypass the `/commit` skill's unplanned work detection because the plan is still `in_progress`.

**Rule:** After each mid-flight fix commit that is NOT part of the current plan's phases:

1. Create a result file: `plans/results/YYYY-MM-DD-<slug>.md`
2. Register immediately:
   ```bash
   ./scripts/plan-index.sh add "<description>" "" "unplanned" "plans/results/YYYY-MM-DD-<slug>.md"
   ```
3. Commit the tracking files in the same commit or a follow-up

This ensures `/plan-status` always reflects the full picture — planned and unplanned work alike.

### Why Chronologist Writes Directly

The Chronologist must never return text for the Orchestrator to copy into the plan. That creates a handoff — handoffs get dropped. The Chronologist writes to the file; the Verifier confirms it exists. No middleman, no forget.

## Parallel Verification

Launch guardrails compliance agent in parallel to verify:

- Clean Architecture patterns compliance
- BDD test structure
- Coding standards (no comments, small functions)
- Documentation policy
- **Implementation Log updated for this phase**

## Result Document Template (for unplanned)

```markdown
# <Feature Name> - Implementation Result

## Summary

What was implemented and why.

## Changes Made

- `path/to/file` - Description of changes

## Decisions

- Decision 1: Rationale
- Decision 2: Rationale

## Testing

- Tests added/modified

## Quality Gates

- [x] Unit tests pass
- [x] Lint passes
- [x] Format check passes
```

## Checklist

- [ ] Plan checked/created before implementation
- [ ] Unit tests written first (TDD)
- [ ] No source code comments added
- [ ] Acceptance test added (if applicable)
- [ ] All quality gates pass
- [ ] Artifact immutability preserved (no manual post-build modifications)
- [ ] Configuration externalized (no env-specific values hardcoded)
- [ ] Changes are rollback-safe (no destructive migrations, no breaking APIs without versioning)
- [ ] Guardrails compliance verified
- [ ] Plan status updated to done
