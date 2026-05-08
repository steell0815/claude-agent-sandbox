# Session Programming Model

Compact reference for the four disciplines active in every session. Loaded by `/init`.

## 1. Strict TDD

Every code change follows red → green → refactor → commit:

```
1. Write a failing test (RED)
2. Write the simplest code to pass (GREEN)
3. Refactor if needed, tests stay green (REFACTOR)
4. Commit immediately (COMMIT)
5. Repeat
```

- Bug fixes: failing test reproducing the bug FIRST, then fix
- No code without a test. No fix without a test. No exception.
- Each commit represents exactly one TDD cycle

## 2. Four-Agent Orchestration

All plan-based (non-trivial) work uses four agents:

| Agent | Role | Runs Where |
|-------|------|-----------|
| **Orchestrator** | Splits plan into phases, coordinates, reports to user | Main conversation |
| **Implementor** | Writes code via strict TDD | Git worktree (isolated) |
| **Verifier** | Runs tests, checks guardrails, validates scope | Against implementor's worktree |
| **Chronologist** | Documents each phase in the plan's Implementation Log | Updates plan file |

### Protocol per phase

```
Orchestrator → launches Implementor (worktree)
Implementor  → signals phase complete
Orchestrator → launches Verifier + Chronologist in parallel
Verifier     → PASS: proceed to next phase
             → FAIL: Orchestrator resumes Implementor with failure details
Chronologist → appends phase entry to plan Implementation Log
Orchestrator → commits phase, reports status to user
```

### Commit cadence

One commit per successful Implementor → Verifier → Chronologist cycle. Each commit message describes what was implemented and verified.

## 3. BDD Four-Layer Test Architecture

Behavior tests follow four layers:

```
Test → DSL → Protocol Driver → SUT
```

| Layer | Responsibility | Changes When |
|-------|---------------|-------------|
| **Test** | Intent-focused scenarios, no implementation details | Requirements change |
| **DSL** | Domain language API, stable interface | Domain language evolves |
| **Protocol Driver** | Handles IO — Domain (direct), Controller (HTTP), UI (Playwright) | Technology changes |
| **SUT** | The running application | Implementation changes |

### Driver variants

Same abstract test, different execution:
- **Domain Driver**: Direct interactor calls (fast, no framework)
- **Controller Driver**: HTTP via TestClient (validates full stack)
- **UI Driver**: Playwright browser automation (validates end-to-end)

### Directory convention

```
tests/acceptance/<feature>/
  <Feature>Test.{ts,py}           # Scenarios (driver-agnostic)
  <Feature>DSL.{ts,py}            # Domain-specific language
  <Feature>DomainDriver.{ts,py}   # Direct calls
  <Feature>ControllerDriver.{ts,py}  # HTTP
  <Feature>PlaywrightDriver.{ts,py}  # E2E
```

## 4. Guardrails

18 Instant Failures (IF-01 through IF-18) — non-negotiable, must fix before commit.
18 Golden Rules (GR-01 through GR-18) — principles, use judgment.

Before every commit: run `/check-guardrails` on staged changes.

Key instant failures to internalize:
- **IF-01**: No framework imports in domain center
- **IF-07**: No business logic outside domain center
- **IF-12**: No untested code changes
- **IF-13**: No duplicated logic across files

## Discipline Summary

```
Write failing test → Pass it → Refactor → Check guardrails → Commit
                     ↑                                          │
                     └──────────── next cycle ───────────────────┘
```

For plan-based work, wrap this cycle in the 4-agent orchestration pattern.
For acceptance tests, use the 4-layer BDD architecture.
Every green cycle produces a commit. No exceptions.
