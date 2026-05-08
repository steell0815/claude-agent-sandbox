# /decompose - Plan Decomposition

Break down plan stories into sub-tasks when complexity exceeds thresholds. Reduces cognitive load per Implementor invocation and isolates dependencies.

## Prerequisites

- Plan must exist with a completed `/assess-readiness` assessment
- JIRA integration configured (for sub-task creation)

## Arguments

- `<plan-id>`: Plan ID from index (e.g., `S2P-2`)
- `[--threshold-composite=N]`: Composite score threshold (default: 1.5)
- `[--threshold-dimension=N]`: Any single dimension score threshold (default: 2)
- `[--force]`: Decompose all stories regardless of thresholds

## When to Use

Run `/decompose` after `/assess-readiness` when:

- Composite score > 1.5, OR
- Any dimension scores > 2, OR
- `/assess-readiness` recommended decomposition (YELLOW+ band)

`/assess-readiness` should suggest `/decompose` automatically when thresholds are exceeded.

## Workflow

### 1. Read Plan and Assessment

Parse the plan file using the plan parser script:

```bash
./scripts/parse-plan-markdown.sh "plans/<plan-id>.md"
```

This returns JSON with `stories` (phases), `assessment` (dimension scores, composite, band), and other plan data.

If `assessment` is `null`, error: "Run `/assess-readiness <plan-id>` first."

### 2. Identify Decomposition Candidates

A story is a decomposition candidate if it contributes to any dimension scoring above threshold. Analyze each story's contribution:

| Dimension | What makes a story contribute |
|-----------|-------------------------------|
| Cognitive Complexity | Multiple concepts in one story (entity + state machine, orchestration + persistence) |
| BDD Verification | Story requires multiple distinct test scenarios |
| Dependencies | Story touches multiple modules or crosses bounded contexts |
| Pattern Density | Story implements more than one architectural pattern |
| IO Boundary Breadth | Story introduces or touches multiple IO boundaries |

Stories that are already atomic (single concept, single module, single pattern) are **not decomposed** — flag them as "atomic, no decomposition needed."

### 3. Design Sub-Tasks for Each Candidate

For each candidate story, apply these decomposition strategies:

**By concept** — Split when a story mixes distinct domain concepts:
```
"Define entity + VO + enum" →
  Sub-task 1: RuntimeId value object
  Sub-task 2: RuntimeStatus enum with transition validation
  Sub-task 3: ReplicationRuntime entity
```

**By layer** — Split when a story spans multiple architectural layers:
```
"Implement CauseDispatcher" →
  Sub-task 1: Dispatch loop (resolve interactor + execute)
  Sub-task 2: Atomic boundary (save state + append tuple)
  Sub-task 3: Integration test with InMemory doubles
```

**By driver** — Split BDD tests by driver variant:
```
"BDD acceptance test" →
  Sub-task 1: DSL interface + AbstractTest
  Sub-task 2: DomainDriver + DomainAcceptanceTest
  Sub-task 3: ControllerDriver + ControllerAcceptanceTest
```

**By IO boundary** — Split when a story touches multiple IO systems:
```
"Implement JDBC stores" →
  Sub-task 1: JDBC RuntimeStore + migration
  Sub-task 2: JDBC CauseEffectStore + migration
```

### 4. Validate Decomposition

For each proposed sub-task, verify:

1. **Single concern** — sub-task addresses exactly one concept/layer/boundary
2. **Independent testability** — sub-task can be tested in isolation
3. **Clear done criterion** — obvious when the sub-task is complete
4. **No circular dependencies** — sub-tasks can be ordered sequentially

If a sub-task still scores high on any dimension, decompose further (recursive).

### 5. Create Sub-Tasks in JIRA

For each decomposed story, create JIRA Sub-Tasks:

```
mcp__jira__jira_create_issue({
  projectKey: "<project>",
  issueType: "Sub-Task",
  parentKey: "<story-key>",
  summary: "<sub-task summary>",
  description: "<what to implement, acceptance criteria>"
})
```

### 6. Update Plan File

Update the plan's phase section to reflect sub-tasks. Replace the monolithic phase with sub-phases:

**Before:**
```markdown
### Phase 6: CauseDispatcher (S2P-15)

- Orchestration engine in app module
- Flow: load state → resolve interactor → execute → save state → append tuple
- Atomic boundary: all operations succeed or fail together
- TDD with InMemory doubles
```

**After:**
```markdown
### Phase 6: CauseDispatcher (S2P-15)

#### 6a: Dispatch loop (S2P-27)
- Resolve interactor via InteractorRegistry
- Execute interactor: (Cause, Entity) → DecisionResult
- TDD with InMemory InteractorRegistry

#### 6b: Atomic boundary (S2P-28)
- Save new entity state via RuntimeStore
- Append cause/effect tuple via CauseEffectStore
- All operations succeed or fail together
- TDD with InMemory stores

#### 6c: Integration test (S2P-29)
- End-to-end CauseDispatcher test with all InMemory doubles
- Verify: dispatch StartReplication → entity RUNNING + effect recorded
```

Update the `## Status` section to include sub-task checkboxes:

```markdown
- [ ] Phase 6: CauseDispatcher (S2P-15)
  - [ ] 6a: Dispatch loop (S2P-27)
  - [ ] 6b: Atomic boundary (S2P-28)
  - [ ] 6c: Integration test (S2P-29)
```

### 7. Update Sync Snapshot

Update `plans/.sync/<plan-id>.json` to include the new sub-task stories.

### 8. Push to JIRA

Update the epic description via `~/.claude/scripts/jira-update-description.sh` with the refined stories table (parent stories + sub-tasks) and updated assessment.

### 9. Output Decomposition Report

```
══════════════════════════════════════════════
 DECOMPOSE: <plan-id> — <title>
══════════════════════════════════════════════

 Assessment: X.X BAND
 Threshold:  composite > 1.5 or dimension > 2

 Decomposed:
  S2P-15  CauseDispatcher          3 sub-tasks (by layer)
    → S2P-27  Dispatch loop
    → S2P-28  Atomic boundary
    → S2P-29  Integration test

  S2P-16  BDD acceptance test      3 sub-tasks (by driver)
    → S2P-30  DSL + AbstractTest
    → S2P-31  DomainDriver
    → S2P-32  ControllerDriver

 Unchanged (atomic):
  S2P-10  Entity + VO + enum       (single module, single concern)
  S2P-11  Cause + Effect types     (single module, single concern)
  S2P-12  Pure interactor          (single module, single concern)
  S2P-13  Store ports              (single module, single concern)
  S2P-14  InMemory test doubles    (single module, single concern)

 Created: 6 sub-tasks in JIRA
 Plan: phases updated with sub-phases
 Snapshot: plans/.sync/<plan-id>.json updated
══════════════════════════════════════════════
```

## Rules

- **Assessment required** — This skill will not run without a completed `/assess-readiness` assessment in the plan file.
- **Atomic stories are not decomposed** — Stories that address a single concept in a single module with a single pattern stay as-is. Decomposing them is overhead, not simplification.
- **Sub-tasks must be independently testable** — If a sub-task cannot be verified in isolation, the decomposition is wrong. Merge it back or recut.
- **Decomposition is recursive** — If a sub-task still exceeds thresholds after one round, decompose further. Stop when all sub-tasks are atomic.
- **Plan file is the source of truth** — Sub-tasks are documented in the plan first, then pushed to JIRA. Never create JIRA sub-tasks without updating the plan.
- **JIRA sync follows repo-as-truth** — Sub-task creation pushes from plan to JIRA via the standard sync model.
- **Implementor scope = one sub-task** — After decomposition, `/implement-feature` should give the Implementor agent one sub-task at a time, not the entire parent story. This is the primary benefit of decomposition.
- **Status rolls up** — A parent story is Done only when all its sub-tasks are Done. The plan's phase checkbox reflects the parent, sub-task checkboxes are indented beneath it.
