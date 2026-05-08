# Workflows

Step-by-step guides for common development tasks. Follow these workflows to ensure all circles stay in sync and no steps are missed.

## 1. Create New Domain Feature

Use this workflow when implementing a new feature from scratch.

### Steps

1. **Read knowledge** — Check `.claude/features/{domain}.md` for existing context. If it doesn't exist, create it from the template after completing the feature.

2. **Build Entities** — Create the entity, value objects, and store port. Write unit tests for all business rules and state transitions. No framework code.

3. **Build Interactors / Use Cases** — Create the use case classes and interactor facade. Wire domain operations through use cases. Write unit tests with in-memory test stores.

4. **Build Store Adapter** — Create the store adapter, persistence model (if needed), mapper (if needed), and migration. Write integration tests for persistence and mapping.

5. **Define API contract** — In case there is public API, create API endpoint design: HTTP method, path, request/response shapes. This drives the implementation.

6. **Build Controller** — Create the controller, exception handling, and API endpoint. Wire to interactor. Write controller tests for HTTP behavior.

7. **Build Frontend** (if applicable) — Create the API service, domain model, state store, and UI components. Write unit tests for state logic and component rendering.

8. **Harvest knowledge** — Update or create `.claude/features/{domain}.md` with everything learned. Run `/harvest-knowledge`.

### Quality Check

Before considering the feature complete:
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Acceptance test covers the user-visible behavior
- [ ] No guardrail violations (`/check-guardrails`)
- [ ] Feature knowledge file is up to date

---

## 2. Add a Data Field

Use this workflow when adding a new field to an existing feature. **All representations must be updated in sync** (IF-11: no partial field updates).

### Checklist

| # | Representation | Action | File(s) |
|---|---------------|--------|---------|
| 1 | Domain Entity | Add field to entity or value object, update builder | Entity, Value Object |
| 2 | Store Adapter | Map field in store adapter (both directions, if persistence model exists) | Store Adapter, Mapper |
| 3 | Migration | Create migration to add column | Migration script |
| 4 | Request/Response | Add field to request/response models | Request, Response models |
| 5 | Controller | Ensure field is passed through to interactor | Controller |
| 6 | Frontend API Model | Add field to frontend API response type | API Model |
| 7 | Frontend Domain Model | Add field to frontend domain model and mapper | Domain Model, Mapper |

### Verification

After updating all representations:
- [ ] Unit tests updated and passing (entities, interactors, controller)
- [ ] Integration tests updated and passing (store adapter)
- [ ] Frontend tests updated and passing (if applicable)
- [ ] No `null` or `undefined` for the new field at any boundary

---

## 3. Add Domain Event with Real-Time Sync

Use this workflow when adding a domain event that triggers real-time updates to the frontend.

### Steps

| # | Circle | Action |
|---|--------|--------|
| 1 | Events | Create Cause event (`{Verb}{Entity}`) with request fields |
| 2 | Events | Create Effect event (`{Entity}{PastTenseVerb}`) with result fields |
| 3 | Interactor | Publish effect event after successful execution in the use case |
| 4 | Application | Implement event dispatcher/listener that forwards to real-time channel (WebSocket, SSE) |
| 5 | Frontend (API) | Create event model matching the backend event structure |
| 6 | Frontend (State) | Handle incoming event: update local state, trigger UI refresh |

### Rules

- Events are published **after** the transaction commits (never before)
- Event consumers must be **idempotent** (events may arrive more than once)
- Frontend handlers must be **defensive** (handle missing fields, unknown event types)

---

## 4. Add Domain Settings

Use this workflow when adding a settings/configuration feature managed through the domain.

### Steps

| # | Circle | Action |
|---|--------|--------|
| 1 | Entity | Create settings value object with validation |
| 2 | Entity | Add store port for settings persistence |
| 3 | Events | Create cause event (`UpdateSettings`) and effect event (`SettingsUpdated`) |
| 4 | Application | Create migration for settings table/collection |
| 5 | Application | Create store adapter (with optional persistence model) |
| 6 | Interactor | Create use case (`UpdateSettingsUseCase`) with business rules |
| 7 | Interactor | Create interactor facade |
| 8 | Application | Create controller with GET/PUT endpoints |
| 9 | Frontend | Create state store, API service, and settings UI |
| 10 | Tests | Unit (entities, interactors), integration (store adapter), acceptance (end-to-end) |

---

## 5. Before Committing

Run through this checklist before every commit.

### Pre-Commit Checklist

- [ ] **Tests pass** — All unit, integration, and acceptance tests are green
- [ ] **Lint passes** — No linting errors or warnings
- [ ] **Format check passes** — Code is formatted according to project standards
- [ ] **No guardrail violations** — Run `/check-guardrails` against staged changes
- [ ] **Feature doc updated** — If domain work was done, `.claude/features/{domain}.md` is current
- [ ] **No secrets** — No passwords, API keys, tokens, or connection strings in staged files
- [ ] **No environment-specific values** — No hardcoded URLs, ports, or host names
- [ ] **Glossary updated** — If new domain terms were introduced, `docs/glossary.md` is updated
- [ ] **ADR written** — If an architectural decision was made, it's captured in an ADR

---

## 6. Pipeline Stage Verification

Use this workflow to understand what each pipeline stage validates. See [ADR-014](../docs/adr/adr-014-pipeline-stages.md) for the full decision record.

### Stage 1: Commit Stage (every push/PR)

Fast feedback — target under 5 minutes.

| Check | Tool (examples) | Gate |
|-------|-----------------|------|
| Formatting | Prettier / Checkstyle | Must pass |
| Linting / static analysis | ESLint / SonarCloud | Must pass |
| Type checking | TypeScript / javac | Must pass |
| Unit tests | Jest / JUnit | Must pass |
| Code coverage | JaCoCo / v8 | Meets threshold per circle (GR-09) |
| Incremental mutation testing | PiTest / Stryker (`--since`) | ≥ 80% killed on changed files |
| SAST scan | SonarCloud | No blocking findings |

### Stage 2: Acceptance Stage (after commit stage)

Proves the system behaves correctly from the user's perspective.

| Check | What It Proves | Gate |
|-------|----------------|------|
| BDD acceptance tests (domain driver) | Business logic correct without infrastructure | Must pass |
| BDD acceptance tests (controller driver) | HTTP contract correct | Must pass |
| BDD acceptance tests (UI driver) | User-visible behavior correct | Must pass |
| Security acceptance tests | Authentication, authorization, data isolation | Must pass |
| SBOM generation | CycloneDX bill of materials | Generated |

### Stage 3: DAST Stage (daily + manual)

Dynamic security scanning against a running application.

| Check | What It Proves | Gate |
|-------|----------------|------|
| OWASP ZAP baseline scan | No runtime vulnerabilities | No high-severity findings |
| Dependency scanning | No critical CVEs in dependencies | No critical vulnerabilities |

### Nightly: Full Mutation Analysis

| Check | What It Proves | Gate |
|-------|----------------|------|
| Full-codebase mutation testing (PiTest / Stryker) | Test effectiveness across all modules | Informational (trend tracking, not gating) |

### Continuous

| Check | Frequency | Gate |
|-------|-----------|------|
| Dependabot / dependency scanning | Daily | Critical vulnerabilities block deployment |

---

## 7. Playground (Throwaway Experiments)

Use this workflow when you need a local scratch space for hypothesis proofing, state tracing, API experiments, or other throwaway code.

### When to Use

- You need to verify a hypothesis before committing to an approach
- You want to trace state flow or debug a complex interaction
- You're experimenting with an external API or library
- You need a quick proof-of-concept that doesn't belong in production code

### Steps

1. **Create directory** — Create `playground/` at the project root. It's gitignored and will never be committed.
2. **Write throwaway code** — Add scripts, snippets, or scratch files. No naming conventions or quality gates apply.
3. **Learn and discard** — Extract the insight, apply it to production code via TDD, then delete `playground/` when done.

### Rules

- **Gitignored** — `playground/` is listed in `.gitignore`. Contents are never committed.
- **Not a substitute for TDD** — Production code still follows strict TDD. Playground code validates ideas; production code validates correctness.
- **ADR-007 still applies** — Time-boxed spikes that inform production decisions must follow [ADR-007](../docs/adr/adr-007-spikes-for-uncertainty.md). The playground is for personal scratch work, not formal spike output.
- **Delete when done** — Remove the directory once the experiment is complete. Don't let scratch code accumulate.

---

## 8. Analyze External Repository

Use this workflow when you want to analyze an external git repository for practices worth adopting into the blueprint. See [ADR-017](../docs/adr/adr-017-repository-analysis-for-blueprint-evolution.md) for the full decision record.

### When to Use

- You've seen a well-structured project and want to capture its practices
- You've forked a blueprint-derived project and want to detect evolved practices (drift mode)
- You want a systematic comparison of another repo's architecture against the blueprint

### Steps

1. **Run the skill** — Invoke `/analyze-repo <path>` with the target repository path.

   ```
   /analyze-repo ~/projects/my-spring-app
   /analyze-repo ~/projects/my-spring-app --drift
   /analyze-repo ~/projects/my-spring-app --categories adr,testing
   ```

2. **Validation** — The skill verifies the target is a git repository, detects its tech stack, and suggests drift mode if the repo is blueprint-derived.

3. **Baseline indexing** — The current blueprint state (ADRs, guardrails, workflows, layer docs, stacks) is loaded as the comparison baseline.

4. **Parallel analysis** — Four specialist analysts examine the target repo:

   | Analyst | Focus |
   |---------|-------|
   | `adr-analyst` | Architectural decisions |
   | `practice-analyst` | Guardrails, patterns, workflow |
   | `test-analyst` | Testing patterns and quality measurement |
   | `pipeline-analyst` | CI/CD, security, deployment |

5. **Ranking** — Each finding is scored on novelty, generality, evidence, and alignment (0-10 each, minimum 20/40 to proceed). Duplicates are merged, max 15 findings advance.

6. **PR creation** — Each accepted finding becomes a branch (`analyze/{repo-name}/{slug}`) with a PR containing hypothesis, evidence, and proposed blueprint change.

7. **Summary report** — Results are saved to `.agents/playgrounds/ANALYSIS-{id}/results.md`.

### Rules

- The target repository is **read-only** — never modified
- Every PR contains a **hypothesis** explaining why the practice belongs in the blueprint
- Every PR contains **concrete evidence** (quoted code/config) from the target
- Findings must be **general enough** to apply across stacks — project-specific patterns are excluded
- Maximum **15 PRs** per analysis run
- Contradictions with existing ADRs are **reported but never committed**

## 9. Pre-commit Auto-Fix-Validate Pipeline

A three-phase automated pre-commit pipeline that eliminates formatting defects without developer friction. Rather than rejecting commits for fixable issues, the hook fixes what it can, re-stages the changes, then validates what cannot be auto-fixed.

### Phase 1: Auto-Fix

Run deterministic auto-fixers on staged files:
- Formatting corrections (Prettier, Checkstyle auto-fix, trailing whitespace)
- Version stamping (see ADR-022)
- Import sorting, line ending normalization

**Key rule:** Auto-fixers must be deterministic and idempotent. Running them twice produces the same output.

### Phase 2: Re-Stage

Re-stage any files modified by Phase 1:

```bash
git diff --name-only | xargs git add
```

This ensures the commit contains the fixed versions, not the original.

### Phase 3: Validate and Gate

Run validation checks that cannot be auto-fixed:
- Guardrail violations (`/check-guardrails`)
- Repository integrity (`git fsck --full --no-dangling`)
- Content validation (required metadata, broken links, structural rules)

**Error-severity failures block the commit.** Warnings are displayed but non-blocking.

### Skip Mechanism

For exceptional cases, allow bypassing with an environment variable:

```bash
SKIP_VALIDATION=1 git commit -m "emergency fix"
```

This must be rare and documented. CI will still catch issues.

### Parity with CI

The pre-commit hook should mirror CI checks so developers get fast local feedback. CI remains the authoritative gate — pre-commit is a convenience that reduces failed pipelines.
