# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Session Entry Point

Run `/init` at the start of every session. It loads the programming model, detects in-progress plans, identifies the work context, and routes to the correct workflow. See `.claude/session-model.md` for the compact reference.

## Critical Thinking Process

Before writing any code, run through this 5-step checklist:

1. **Identify domain** — Read `.claude/features/<domain>.md` FIRST. If it exists, absorb context before making changes.
2. **Identify circle** — Determine which Clean Architecture circle you're working in and consult the matching `.claude/*-layer.md` for rules and patterns.
3. **Check guardrails** — Scan `.claude/guardrails.md` instant failures. If your planned change would violate any rule, stop and redesign.
4. **Sync check** — If modifying a data field, run through the field sync checklist in `.claude/workflows.md` (Workflow 2: Add a Data Field).
5. **Harvest knowledge** — After completing work, update `.claude/features/<domain>.md` with what you learned.

## Documentation Map

| File | When to Consult |
|------|-----------------|
| [`.claude/guardrails.md`](.claude/guardrails.md) | Before every code change — check instant failures and golden rules |
| [`.claude/naming-conventions.md`](.claude/naming-conventions.md) | When creating new types, files, or API endpoints |
| [`.claude/domain-layer.md`](.claude/domain-layer.md) | When working on entities, value objects, interactors, events |
| [`.claude/application-layer.md`](.claude/application-layer.md) | When working on controllers, store adapters, DI config |
| [`.claude/infrastructure-layer.md`](.claude/infrastructure-layer.md) | When working on store implementations, persistence mapping, migrations |
| [`.claude/interfaces-layer.md`](.claude/interfaces-layer.md) | When working on API conventions, error handlers, pagination |
| [`.claude/workflows.md`](.claude/workflows.md) | When starting a new feature, adding a field, or preparing to commit |
| [`.claude/knowledge-harvesting.md`](.claude/knowledge-harvesting.md) | After completing domain work — document what you learned |
| [`.claude/features/<domain>.md`](.claude/features/) | Before and after working on any domain feature |

## Clean Architecture

During development a ubiquitous language must be derived. The terms of this language must be documented and kept up to date in [docs/glossary.md](docs/glossary.md).

### Domain Artifacts

- **Entities**: Immutable, identified by ID. Use fluent builders.
- **Value Objects**: Immutable, defined by attributes.
- **Interactors**: Application-specific business rules orchestrating entities via use cases.
- **Events**: Cause (input) + Effect (output) pairs for event sourcing.
  - Causes designed outside-in, Effects inside-out.
  - Never change existing events; version them.

### Ports and Adapters (Hexagonal Architecture)

- Domain defines ports (interfaces); adapters implement them outside the domain.
- Domain has zero dependencies on infrastructure frameworks.
- Domain tests run without DB, network, or framework — the BDD Domain Driver validates this constraint.
- See [ADR-006](docs/adr/adr-006-ports-and-adapters-for-domain-purity.md).

### Conway's Law

- Architecture mirrors communication structure. Design team communication to produce the desired architecture.
- When architecture and team structure conflict, team structure wins. Align them intentionally.

## BDD Acceptance Testing (4 Layers)

```
Test → DSL → Protocol Driver → SUT
```

1. **Test**: Intent-focused, no implementation details.
2. **DSL**: Domain language, stable API.
3. **Protocol Driver**: Handles IO/protocol (Domain/Controller/UI variants).
4. **SUT**: The running application.

### Test Variants

Same abstract test, different execution:

- **Domain Test**: Direct interactor calls (fast, no framework)
- **Controller Test**: HTTP-level testing (MockMvc / Supertest)
- **UI Test**: Playwright browser automation

### BDD Directory Convention

```
test/acceptance/<feature>/
  <Feature>DSL.{ts,java}           # Domain-specific language interface
  <Feature>Test.{ts,java}          # Abstract test scenarios
  <Feature>DomainDriver.{ts,java}  # Unit test driver (fast)
  <Feature>ControllerDriver.{ts,java}  # HTTP driver
  <Feature>PlaywrightDriver.{ts,java}  # E2E driver
```

## Coding Standards

- **Strict TDD**: Failing test → simplest passing code → refactor.
- **Readability over cleverness**: Code should be obvious, not impressive. If a solution requires explanation, simplify it.
- Small functions, meaningful names.
- Injectable/testable dependencies.
- Use stable selectors (`data-testid`) for UI tests.
- Avoid sleeps; use explicit waits.

### Design Principles

- **Dual Quality Criteria** — Code must work correctly AND be easy to change. Neither alone is sufficient. *(Ref: Farley / Ch. 3)*
- **SOLID Through Tests** — SRP: one reason to change per module. OCP: extend by composition. DIP: domain owns interfaces, adapters implement them. Tests enforce all three.
- **Coupling and Cohesion** — Loose coupling is a professional ethic. High coupling multiplies cost of every future change. Group code by shared intent (cohesion), not technical layer.
- **Refactoring Is Internal Structure Change Only** — Not a synonym for rewrite, fix, or feature addition. Misusing the term undermines professional communication.
- **Technical Debt Is Managed** — TDD is a debt-management practice. Track debt explicitly, repay intentionally, never confuse sloppiness with speed.

### Documentation Policy

**No source code comments** except when strictly necessary:

- **Regular expressions**: Always document the pattern's intent.
- **Workarounds for third-party bugs**: Document the bug, link to issue tracker if available.
- **Non-obvious algorithms**: Only when simplification is not possible.

Comments that describe _what_ code does are forbidden — the code itself must be self-explanatory through good naming and structure. If code needs a comment to be understood, refactor it instead.

### Quality Gates (Definition of Deployable)

All gates must pass before an artifact is considered deployable (see [ADR-001](docs/adr/adr-001-adopt-minimum-cd.md), [ADR-014](docs/adr/adr-014-pipeline-stages.md)):

**Commit Stage** (every push):
- Formatting (Prettier / Checkstyle)
- Linting (ESLint / static analysis)
- Type checking
- Unit tests passing
- Code coverage (JaCoCo / v8 — meets threshold per circle)
- Incremental mutation testing (PiTest / Stryker — ≥ 80% killed on changed files)
- SAST scans: application code (Semgrep/SonarCloud), Dockerfiles (Hadolint), shell scripts (ShellCheck), dependencies (Trivy) — all must pass

**Acceptance Stage** (after commit):
- BDD acceptance tests passing (domain, controller, UI drivers)
- SBOM generation (CycloneDX)

**DAST Stage** (daily + manual):
- OWASP ZAP baseline scan (no high-severity findings)
- Dependency scanning (Dependabot — no critical vulnerabilities)

## Skills (Reusable Workflows)

The following skills are available in `.claude/skills/` to reduce token consumption:

### Session

| Skill          | Command           | Description                                         |
| -------------- | ----------------- | --------------------------------------------------- |
| `/init`        | Session bootstrap | Load programming model, detect plans, route to workflow |
| `/dashboard`   | Session dashboard | Show hooks, skills, settings, active agents, git state |
| `/capabilities`| Session inventory | Quick list of all tools, skills, hooks, MCPs, agents |
| `/agents`      | Agent monitor     | List active/recent subagents and view their logs |

### Development Workflow

| Skill          | Command       | Description                                         |
| -------------- | ------------- | --------------------------------------------------- |
| `/commit`      | Git commit    | Stage files, create commit with conventions, verify | `./scripts/commit-helper.sh` (unplanned tracking) |
| `/push`        | Git push      | Push to remote with verification                    | |

### Plan Management

| Skill            | Command       | Description                                         | Script |
| ---------------- | ------------- | --------------------------------------------------- | ------ |
| `/plan`          | Create plan   | Create structured implementation plan before coding | `./scripts/plan-init.sh` |
| `/plan-status`   | View plans    | Display status of all implementation plans          | `./scripts/plan-status.sh` |
| `/complete-plan` | Complete plan | Mark an implementation plan as done                 | `./scripts/complete-plan.sh` |
| `/sync-jira`     | JIRA sync     | Snapshot-based three-way merge between plans and JIRA | `./scripts/jira-sync.sh` |

### Feature Development

| Skill               | Command       | Description                                        |
| ------------------- | ------------- | -------------------------------------------------- |
| `/implement-feature` | TDD workflow | TDD implementation with plan integration           |
| `/review-pr`        | PR review     | Review pull request against project standards      |

### Architecture & Quality

| Skill               | Command             | Description                                             |
| ------------------- | ------------------- | ------------------------------------------------------- |
| `/add-adr`          | Create ADR          | Create new ADR from template, assign number, update index |
| `/add-guardrail`    | Add guardrail rule  | Add instant failure or golden rule to guardrails.md          |
| `/check-guardrails` | Review guardrails   | Check staged changes against all instant failure/golden rules | `./scripts/guardrails-check.sh` (pre-scan) |
| `/harvest-knowledge`| Update feature docs | Create or update `.claude/features/<domain>.md`         | |
| `/analyze-repo`     | Analyze repository  | Analyze git repo for practices to adopt into the blueprint   | |
| `/assess-readiness` | Complexity assessment | Score implementation complexity across 8 dimensions, determine preparation needs | `./scripts/assessment-publish.sh` (JIRA push) |
| `/decompose`        | Plan decomposition   | Break down stories into sub-tasks when complexity exceeds thresholds             | |

Plan workflow:

1. Create plan with `/plan <feature-name>` before implementation
2. Assess readiness with `/assess-readiness <plan-id>` to evaluate complexity
3. If composite > 1.5 or any dimension > 2, run `/decompose <plan-id>` to break down complex stories
4. Use `/implement-feature` which automatically checks for existing plans and assessments
4. Track progress with `/plan-status`
5. Mark complete with `/complete-plan <id>`

Plans are stored in `plans/` directory with an index at `plans/index.json`.
Unplanned implementations are tracked in `plans/results/`.

### Usage

Invoke skills by name (e.g., `/commit`) to execute the documented workflow. Skills encapsulate multi-step operations that follow project conventions.

## Knowledge Harvesting

Feature knowledge files in `.claude/features/` provide AI-readable context for each domain area. Before starting domain work, **always read the relevant feature file first**. After completing domain work, **always update it**.

- **Read**: `.claude/features/<domain>.md` before starting work
- **Write**: Update the file after completing work (or create from `.claude/features/TEMPLATE.md`)
- **Use**: `/harvest-knowledge` skill to automate the process

See [`.claude/knowledge-harvesting.md`](.claude/knowledge-harvesting.md) for full rules.

## Multi-Agent Orchestration

All non-trivial implementation tasks (any plan-based work) **must** use a 4-agent orchestration pattern. This is the default standard approach — never fall back to single-agent sequential implementation.

### Agent Roles

| Role | Responsibility | Execution |
|------|---------------|-----------|
| **Orchestrator** | Coordinates all agents, reports progress/completion/blockers to user | Main conversation thread |
| **Implementor** | Writes code following strict TDD and the plan; evolves design through red-green-refactor | Runs in a git worktree for isolation |
| **Verifier** | Validates implementor's work — runs tests, checks guardrails, verifies coverage, **confirms Implementation Log was updated** | Runs against implementor's worktree |
| **Chronologist** | Documents every phase by **writing directly** to the plan file — never returns text for the Orchestrator to relay | Appends to `## Implementation Log` in the plan file after each phase completes |

### Orchestration Protocol

```
1. Orchestrator reads the plan and splits it into phases
2. For each phase:
   a. Orchestrator launches Implementor (worktree) with phase context
   b. Once Implementor signals phase complete:
      - Orchestrator launches Chronologist to write directly to plan file
      - Orchestrator launches Verifier against the worktree
        (Verifier checks include: Implementation Log entry exists for this phase)
   c. If Verifier finds failures:
      - Orchestrator resumes Implementor with failure details
      - Cycle repeats until Verifier passes
   d. Orchestrator reports phase status to user
3. After all phases pass, Orchestrator merges worktree changes
```

**Critical:** The Chronologist **must write** to the plan file itself (using Edit/Write tools). It must never return text for the Orchestrator to relay — that creates a handoff that can be dropped. The Verifier then confirms the log entry exists as part of its checklist.

### Agent Verification

The SubagentStop hook validates agent completion:
- **Implementor**: Checks Implementation Log exists and at least one commit was made
- **Verifier**: Checks attestation file exists with all 5 fields true
- **Chronologist**: Checks plan file was modified
- **Other agents**: Pass through without verification

Verification results are logged to `.claude/cache/agent-history.jsonl`. Currently non-blocking (observability only).

### Status Reporting

The Orchestrator must inform the user at these points:
- **Phase start**: Which phase is beginning, what it covers
- **Phase complete**: What was implemented, verification status
- **Blocker**: What failed, what the recovery plan is
- **All done**: Summary of all phases completed

### Plan Documentary

The Chronologist appends to the plan file under a `## Implementation Log` section:

```markdown
## Implementation Log

### Phase N: <name> — <status>
**Started:** <timestamp>
**Completed:** <timestamp>
**Files created/modified:** <list>
**Tests:** <pass count> passing, <fail count> failing
**Key decisions:** <any TDD-driven design evolution>
**Verification:** <guardrail check result>
```

## Common Workflows

Structured step-by-step guides are available in [`.claude/workflows.md`](.claude/workflows.md):

1. **Create New Domain Feature** — Full 8-step guide from knowledge read to knowledge harvest
2. **Add a Data Field** — Field sync checklist to prevent partial updates (IF-11)
3. **Add Domain Event with Real-Time Sync** — 5-layer guide for event-driven features
4. **Add Domain Settings** — 11-step guide for configuration features
5. **Before Committing** — Pre-commit checklist for every change
6. **Pipeline Stage Verification** — Three-stage pipeline model (commit, acceptance, DAST)
7. **Playground (Throwaway Experiments)** — Gitignored scratch space for hypothesis proofing and API experiments
8. **Analyze External Repository** — Compare repo against blueprint baseline, create PRs for discoveries
9. **Pre-commit Auto-Fix-Validate Pipeline** — Three-phase hook: auto-fix, re-stage, validate-and-gate
