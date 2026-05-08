# Guardrails

This document defines the non-negotiable rules and guiding principles for all development in this project. Every code change must comply with these guardrails.

## Instant Failures (NEVER DO THIS)

Any of these violations must be fixed immediately. They are never acceptable, regardless of context.

| # | Rule | Why |
|---|------|-----|
| IF-01 | No framework code in domain center (annotations, decorators, ORM imports) | Domain must be pure; infrastructure leaks couple business logic to technology choices |
| IF-02 | No query string concatenation (SQL, NoSQL, LDAP) | Injection vulnerabilities — always use parameterized queries or query builders |
| IF-03 | No null returns where absent-value types exist (Optional, Maybe, nullable types) | Null propagation causes NullPointerException / TypeError at unexpected call sites |
| IF-04 | No leaking internal data structure without an explicit contract | Couples internal schema to public contract; schema changes break clients. Note: a separate persistence model is NOT required — entities may serialize directly when the entity IS the contract. |
| IF-05 | No internal error leakage (stack traces, SQL errors, internal paths in responses) | Information disclosure vulnerability — attackers use internals to craft exploits |
| IF-06 | No mutable events, request models, or response models | Shared mutable state causes race conditions and unpredictable behavior |
| IF-07 | No business logic outside the domain center (entities, interactors, events) | Controllers, config, and adapters must not contain business rules — business logic belongs in entities and interactors |
| IF-08 | No unbounded data handling without acceptance test coverage | Unbounded datasets must have acceptance tests proving bounded behavior (pagination, filtering). In-memory stores are valid for testing and bounded data. |
| IF-09 | No in-memory sequence generation (counters, IDs that reset on restart) | Produces duplicates after restart; use database sequences or distributed ID generators. Note: applies to production persistence, not test doubles or bounded reference data. |
| IF-10 | No silent entities (state changes without domain events) | Breaks event-driven workflows and audit trails; other bounded contexts miss updates |
| IF-11 | No partial field updates (missing representations in field sync) | Adding a field to one representation but not others causes data loss or silent null propagation |
| IF-12 | No untested code changes | Untested code is unverified code — it may work by accident today and fail silently tomorrow |
| IF-13 | No duplicated logic across files | Duplication means bugs must be fixed in multiple places; one will be missed |
| IF-14 | No hardcoded secrets (passwords, API keys, tokens, connection strings) | Secrets in code end up in version history and are trivially extractable |
| IF-15 | No missing API prefix on controllers | Inconsistent API paths break routing conventions and make versioning impossible |
| IF-16 | No list endpoints without acceptance test proving bounded results | List endpoint behavior (pagination, max result size) must be proven by acceptance tests, not just asserted in prose. |
| IF-17 | No unhandled business exceptions returning 500 | Business rule violations are expected outcomes, not server errors; they need proper error codes |
| IF-18 | No PII, credentials, or financial data in telemetry (spans, metrics, logs, trace attributes) | Telemetry pipelines are less protected than production databases; sensitive data in telemetry creates compliance violations and security exposure |
| IF-19 | No root-user container execution in production Dockerfiles | Running as root grants unnecessary privilege escalation surface; use a USER directive to drop to non-root after build steps |
| IF-20 | No single-entity lookups inside list/paged operations (N+1 queries) | A paginated endpoint returning N rows must not fire N sub-queries for related data; use batch queries (WHERE id IN ...) or JOINs. N+1 problems persist even within bounded result sets and scale linearly with page size |
| IF-21 | No endpoints accepting resource IDs without ownership verification | Endpoints that read or modify user-scoped resources must verify the caller owns that resource; admin-only endpoints must enforce role-based authorization. Missing checks enable Insecure Direct Object Reference (IDOR) — OWASP Top 10 |

## Golden Rules

### 1. Defense-in-Depth Validation (Value Objects)

Validate at every boundary, with the strictest validation in Value Objects.

- **Controller layer**: Validate request format (required fields, types, string lengths)
- **Interactor layer**: Validate business preconditions (existence checks, authorization)
- **Entity layer**: Value Objects enforce invariants at construction time — invalid state is unrepresentable

A Value Object that accepts any input and validates later is not a Value Object. Construction must fail for invalid data.

### 2. Immutability by Default

All domain objects, events, and request/response models are immutable after construction.

- Use language-appropriate immutability mechanisms (records, readonly, frozen objects, final fields)
- State changes produce new instances rather than mutating existing ones (via `toBuilder()`)
- Collections exposed from objects must be unmodifiable copies

Mutability is the exception, not the rule, and requires explicit justification.

### 3. Null Safety

Nulls are banned from domain logic. Every function either returns a value or uses an explicit absent-value type.

- Use Optional, Maybe, or nullable type annotations — never raw null returns
- Fail fast when null appears where it shouldn't (constructor guards, assertion methods)
- Empty collections instead of null collections

### 4. Fail Fast

Invalid state must be detected at the earliest possible moment — ideally at construction time.

- Constructors and builders validate all invariants before returning an instance
- Do not defer validation to a separate `validate()` method
- Value Objects and Entities reject invalid input immediately with descriptive error messages

### 5. Entity Design

Entities are consistency boundaries with well-defined state transitions.

- **State machines**: Entities enforce valid state transitions; invalid transitions throw domain exceptions
- **Value Objects**: Encapsulate all business rules about individual values (amounts, dates, identifiers)
- **Invariants**: The entity ensures its invariants hold after every operation
- **Business Focus**: Keep entities business focused — include only what would be there in case there would be no automation
- **Construction**: Use the builder pattern (`@Builder(toBuilder = true)`) for entity construction and modification (see ADR-012)

### 6. Request/Response Mapping

Two distinct model types exist at the API boundary, with explicit mapping:

```
Request/Response Model <--> Domain Entity
```

- **Request Models**: Match the public API contract (what clients send)
- **Response Models**: Match the public API contract (what clients receive)
- **Domain Entities**: Enforce business rules, never exposed directly as API responses unless they ARE the explicit contract

Controllers call interactors directly with request models or cause/effects. No intermediate DTO layer is required.

### 7. Structured Error Handling

Errors are categorized, machine-readable, and never leak internals.

- On HTTP: Return structured error responses with: http-error code, human-readable message, optional field-level details
- Errors are stable, documented, and usable by clients for programmatic handling
- Never include stack traces, SQL statements, or internal class names in responses
- Business rule violations, if initiated by a client return appropriate client error status codes (4xx), not server errors (5xx)
- Error control follows DDD rules. Errors are defined at the level of their first appearance. Errors (eg Java Exceptions) are first class citizens and must be distinctive, reuse is disencouraged. Their attributed distinctiveness define their stable, documented and programmatic handle ability.

### 8. Public API: API-First Development

Define the API contract before implementing Public API.

- Real, intended Public API is a rare case
- API contracts are the source of truth for request/response shapes
- Backend and frontend develop against the contract independently
- Contract changes go through a review process (they affect all consumers)

### 9. Test Coverage by Circle

Coverage percentages and mutation scores are **internal diagnostic indicators** — they signal where to look, not what to conclude. A drop in coverage suggests a conversation about test adequacy; it does not automatically mean the code is wrong. Chasing a number at the expense of design clarity defeats the purpose.

Each Clean Architecture circle has appropriate test types, coverage targets, and mutation testing expectations:

| Circle | Test Type | What It Validates | Coverage Target | Mutation Target |
|--------|-----------|-------------------|-----------------|-----------------|
| Entities | Unit tests | Business rules, invariants, state transitions | ≥ 95% | ≥ 80% killed |
| Interactors | Unit tests (with in-memory stores) | Use case logic, business workflows | ≥ 90% | ≥ 80% killed |
| Adapters (stores) | Integration tests with Fakes (favorably Test Containers) | Store queries, persistence mapping, migrations | ≥ 80% | Not mutated (integration tests) |
| Controllers | Controller tests | HTTP status codes, request/response mapping, error handling | ≥ 80% | Not mutated (contract tests) |
| End-to-end | Acceptance tests on Controller and UI Layer (BDD) | Observable behavior through the full stack | — | — |

**Why these targets:**

- **Entities (≥ 95% / ≥ 80% killed)**: Pure logic with no infrastructure dependencies — if it is not tested here, it is not tested anywhere.
- **Interactors (≥ 90% / ≥ 80% killed)**: Orchestration logic with clear inputs and outputs — slightly lower because some paths involve composition of already-tested entities.
- **Adapters (≥ 80% / not mutated)**: Infrastructure integration — coverage proves wiring correctness, but mutation testing adds little value over integration tests.
- **Controllers (≥ 80% / not mutated)**: Thin translation layer — coverage proves mapping correctness, but mutation testing adds little value over contract tests.

Coverage is enforced by JaCoCo (Java) or v8/c8 (TypeScript). Mutation testing is enforced by PiTest (Java) or Stryker (TypeScript). See [ADR-015](../docs/adr/adr-015-mutation-testing-and-coverage-analysis.md).

#### Documented Exclusions

Good design choices (strategy patterns with many small classes, framework integration points, generated code) can legitimately produce lower coverage without indicating weakness. When a code area cannot reasonably meet its circle's threshold, the exclusion must be documented rather than worked around.

- Each exclusion is recorded in the project's coverage exclusion file ([`docs/coverage-exclusions.md`](../docs/coverage-exclusions.md))
- Each entry must include: the code area excluded, the reason the threshold cannot be met, and the alternative verification (e.g., integration test, manual review, acceptance test)
- Exclusions are reviewed as part of the normal code review process
- Tooling annotations (`@Generated`, `/* v8 ignore next */`, JaCoCo exclude patterns) depend on the stack, but the documentation in `coverage-exclusions.md` is mandatory regardless of which annotation mechanism is used

### 10. Store Search

Store interfaces expose specific query methods. Correct filtering behavior is proven by tests, not prescribed by prose.

- Store interfaces expose specific query methods with filter parameters
- Acceptance tests specify query contracts and prove correct behavior
- In-memory stores are valid for testing
- Database indexes support common query patterns in production stores

### 11. Bounded Results

List operations return bounded result sets. The specific bounding mechanism (pagination, max-size, cursor) is determined by acceptance tests that prove the behavior.

- List endpoints return bounded result sets
- The bounding mechanism is specified and proven by acceptance tests
- Sensible defaults apply when clients do not specify parameters
- The store layer supports bounded queries natively

### 12. Event Publishing (Cause + Effect)

Every significant domain interaction involves Cause and Effect events.

- **Causes**: Imperative input events representing what is requested (`PlaceOrder`, `SubmitActor`). Designed outside-in.
- **Effects**: Past-tense output events representing what happened (`OrderPlaced`, `ActorSubmitted`). Designed inside-out.
- Effects are published after the transaction commits successfully (not before)
- Events are immutable records — once created, never modified
- Events contain only the data consumers need, not the entire entity state
- Events live in a separate module from entities
- Consumers must be idempotent — events may be delivered more than once

### 13. DRY (Don't Repeat Yourself)

Extract shared logic into well-named, reusable components.

- If the same logic exists in two or more places, extract it
- Shared logic lives at the appropriate circle (domain services for domain logic, utilities for infrastructure)
- DRY applies to knowledge, not just code — two identical-looking code blocks that represent different concepts should remain separate

### 14. Secure Coding

Follow secure development lifecycle practices:

- Input validation at system boundaries (API controllers, message consumers, file parsers)
- Output encoding when rendering user-supplied data
- Parameterized queries for all database interactions
- Least privilege for service accounts and API tokens
- Dependency scanning for known vulnerabilities
- No sensitive data in logs (mask PII, tokens, credentials)
- Telemetry signals (spans, metrics, trace attributes) follow the same prohibition — see IF-18 and ADR-018
- Security requirements MUST be proven by BDD acceptance tests running across all drivers. See GR-15.

### 15. Security and Performance are BDD-Provable

Security requirements (authentication, authorization, data isolation) and performance requirements (bounded response sizes, response times) MUST be specified as BDD acceptance tests.

- Same acceptance test runs against domain driver, controller driver, and UI driver
- Security tests prove: unauthenticated access is rejected, unauthorized access is forbidden, data isolation between users
- Performance tests prove: list endpoints return bounded result sets, response times meet SLAs under load
- If you cannot write an acceptance test for a security or performance claim, the claim is unverified

### 16. Mutation Testing Validates Test Effectiveness

Coverage without mutation testing gives false confidence. A test suite that executes every line but asserts nothing meaningful will pass coverage gates while catching no faults. Both coverage and mutation testing must pass on changed code in the Commit Stage.

- Incremental mutation testing runs on changed files only (PiTest `--since` / Stryker `--since`)
- Mutation score ≥ 80% killed on changed files in entities and interactors
- Adapters and controllers are excluded from mutation testing (tested via integration and contract tests)
- Nightly full-codebase mutation runs track trends but do not gate deployments
- See [ADR-015](../docs/adr/adr-015-mutation-testing-and-coverage-analysis.md)

### 17. Assertion-Focused BDD Tests

Each BDD acceptance test has at most 1–2 assertions about one behavioral concern. Tests with >2 assertions must be split following [ADR-016](../docs/adr/adr-016-assertion-focused-bdd-acceptance-tests.md) splitting rules. This ensures failures pinpoint the exact broken effect and enables business feature scoping by including or excluding individual effect verifications.

- Notifications split from domain state → `_notification` suffix
- Audit trail splits from domain state → `_auditTrail` suffix
- Different entity/concern assertions split → descriptive suffix
- Cohesive assertions (≤2 about same entity property) stay together
- Rejection + state-unchanged stays together (one concept: "operation failed")

### 18. Business Function Instrumentation

Every interactor/use case is instrumented with telemetry that measures feature adoption
and operational health. Instrumentation follows OpenTelemetry semantic conventions and
lives in the application layer, never in the domain center.

- Every use case produces: invocation count, duration histogram, outcome label
- Every effect event produces: a published-event counter by event type
- Naming: `business.usecase.invocations`, `business.usecase.duration`,
  `business.event.published` — see ADR-018
- Domain purity: instrumentation code belongs in application layer decorators/wrappers,
  never in entities, value objects, or interactor business logic
- Telemetry is BDD-provable: acceptance tests verify signals are emitted and no
  excluded data appears — see GR-15
- Attribute safety: every span attribute and metric label checked against ADR-018
  exclusion list before recording

### 19. Multi-Tool SAST Coverage

A single SAST tool cannot cover all artifact types in a modern project. The commit stage must orchestrate multiple specialized scanners in parallel, each targeting its artifact type:

- **Application SAST** (e.g., Semgrep, SonarCloud): Language-specific vulnerability detection on source code
- **Dockerfile linting** (e.g., Hadolint): Best-practice enforcement for container definitions (non-root users, pinned base images, minimal layers)
- **Shell script analysis** (e.g., ShellCheck): Detects common shell scripting errors and security issues
- **Dependency and misconfiguration scanning** (e.g., Trivy): Filesystem-level scan for known CVEs in dependencies and infrastructure misconfigurations

Each scanner runs as an independent parallel job. All must pass. Scanner-specific rule suppressions must be documented with rationale (e.g., `DL3007` ignored because base image is internally managed).

### 20. Authorization Integration Testing

Every secured endpoint MUST have authorization integration tests that verify access control enforcement in the commit stage — not just in DAST.

- **401 (Unauthenticated)**: Request without credentials is rejected
- **403 (Forbidden)**: Request with wrong role/scope is rejected
- **200 (Authorized)**: Request with correct role/scope succeeds
- **Public endpoints**: Verify they remain accessible without credentials

Authorization tests use a test security configuration with deterministic tokens (e.g., `admin-token` maps to `ROLE_ADMIN`, `user-token` maps to `ROLE_USER`). This enables fast, repeatable verification without external identity providers.

These tests catch missing authorization annotations (`@PreAuthorize`, middleware guards) before deployment — a gap that DAST scanning alone cannot reliably detect for all endpoints.

### 21. Structured Logging Only

All logging (backend and frontend) MUST go through a structured logging framework or service. Raw console output is banned in production code.

- **Backend**: Use the stack's structured logging framework (SLF4J/Logback, Winston, Python logging) — never `System.out.println`, `print()`, or `fmt.Println()`
- **Frontend**: Use a domain-scoped logging service — never raw `console.log`, `console.error`, or `console.warn`
- **Enforcement**: Lint rules (`no-console`, `no-sysout`) ban raw output; exceptions only for the logging service implementation itself
- **Structure**: Log entries include timestamp, severity, domain context, and structured data — not ad-hoc string concatenation
- **PII safety**: Logging services apply the same exclusion rules as telemetry (see IF-18)

Raw console output in production is a security risk (leaking internals), a maintenance problem (unfilterable, unroutable), and an observability gap (no structured metadata for aggregation).

### 22. Security Response Headers

Web applications MUST configure security response headers to mitigate common browser-based attacks. Headers are infrastructure configuration, not application logic.

| Header | Value | Purpose |
|--------|-------|---------|
| `Content-Security-Policy` | Tailored to application needs | Prevents XSS, clickjacking, and data injection attacks |
| `X-Content-Type-Options` | `nosniff` | Prevents MIME type sniffing |
| `X-Frame-Options` | `DENY` or `SAMEORIGIN` (or use CSP `frame-ancestors`) | Prevents clickjacking |
| `Referrer-Policy` | `strict-origin-when-cross-origin` or stricter | Controls referrer information leakage |
| `Permissions-Policy` | Restrict unused browser features | Limits access to device APIs (camera, geolocation, etc.) |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | Enforces HTTPS (enable only when app terminates TLS directly) |

- CSP must be tailored — overly strict policies break legitimate functionality; overly loose policies provide no protection
- HSTS should be disabled when TLS is terminated at a load balancer or reverse proxy upstream
- Security headers are verified by DAST scanning (Stage 3) but should be configured proactively, not discovered by scanners
- Header configuration is environment-specific and belongs in application configuration, not hardcoded in source

## Layer Dependencies

Dependencies point inward. Everything outside the domain center is a plugin.

| Circle | Contains | May Depend On |
|--------|----------|---------------|
| Entities (center) | Entities, VOs, store ports, domain services | Nothing |
| Interactors | Use cases, interactor facades | Entities |
| Events (module) | Cause/Effect event pairs | Entities |
| Application (outer) | Controllers, store adapters, config, DI | Entities, Interactors, Events |

## Documentation Tiers

| Tier | Where | What |
|------|-------|------|
| Executable | Tests (BDD/TDD) | Expected behavior — the source of truth |
| Structural | ADRs, CLAUDE.md | Architectural decisions and project conventions |
| Operational | Feature docs (`.claude/features/`) | Domain-specific knowledge for AI-assisted development |
| Glossary | `docs/glossary.md` | Ubiquitous language definitions |
| None | Source code comments | Forbidden except for regex, workarounds, and non-obvious algorithms |
