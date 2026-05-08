# ADR-019: Executable Architecture Tests

## Status

Proposed

## Context

The blueprint prescribes Clean Architecture (ADR-008) and Ports and Adapters (ADR-006) with explicit layer dependency rules and domain purity constraints. Guardrails IF-01 ("no framework code in domain center") and IF-07 ("no business logic outside domain center") codify these rules in prose.

However, prose rules are only enforced when read by humans or AI during review. Without automated enforcement, architectural drift accumulates silently — a single misplaced import or annotation creates a precedent that compounds across the codebase. Manual review is insufficient because:

- Layer violations are easy to miss in large diffs
- New team members may not know the rules until they violate them
- AI assistants follow patterns they see in existing code, amplifying violations

Architecture test frameworks (ArchUnit for JVM, dependency-cruiser for Node.js, import-linter for Python) make layer dependency rules, domain purity constraints, and naming conventions executable — violations fail the build in the commit stage.

## Decision

Every blueprint-derived project MUST include automated architecture tests that verify structural constraints as part of the commit stage build. Architecture tests are unit tests that analyze code structure (imports, annotations, naming, package membership) without executing business logic.

### Required Architecture Test Categories

| Category | What It Verifies | Example Rules |
|----------|-----------------|---------------|
| Layer dependencies | Dependency direction follows Clean Architecture circles | Domain may not import from application layer; application may not import from infrastructure |
| Domain purity | Domain center has zero framework dependencies | No ORM annotations, no DI framework imports, no HTTP framework types in domain packages |
| Structural immutability | Domain events, value objects, and DTOs are immutable types | Events must be records/frozen classes; VOs must be records/frozen classes |
| Naming conventions | Types follow the project's naming conventions | Controllers end with `Controller`; stores end with `Store`; events use past tense |

### Architectural Placement

Architecture tests live alongside unit tests and run as part of the commit stage (`mvn test`, `pnpm test`, etc.). They require no infrastructure (no database, no network) and execute in milliseconds.

### Stack-Specific Tooling

| Stack | Tool | Configuration |
|-------|------|---------------|
| JVM (Java, Kotlin) | ArchUnit | `com.tngtech.archunit:archunit-junit5` |
| Node.js / TypeScript | dependency-cruiser | `.dependency-cruiser.cjs` |
| Python | import-linter | `importlinter` in `setup.cfg` |
| .NET | NetArchTest | `NetArchTest.Rules` NuGet |

### Relationship to Existing Guardrails

Architecture tests are the enforcement mechanism for prose guardrails:

| Guardrail | Architecture Test |
|-----------|------------------|
| IF-01: No framework code in domain | Test: domain packages contain no framework imports |
| IF-07: No business logic outside domain | Test: controller/adapter packages contain no domain service logic |
| IF-15: No missing API prefix | Test: all controller classes use consistent path prefix |
| GR-02: Immutability by default | Test: events, VOs, commands are immutable types |

## Consequences

### Positive

- Architectural constraints become self-enforcing — violations fail the build before review
- New team members discover rules through failing tests with descriptive messages
- AI assistants cannot introduce architectural violations that pass CI
- Rules documented in guardrails.md gain a verifiable enforcement mechanism

### Negative

- Initial setup effort per project to configure architecture test framework
- Architecture tests must be maintained as the codebase evolves (new packages, renamed modules)
- May produce false positives during refactoring if package structure changes

### Neutral

- Architecture tests do not replace guardrails documentation — they enforce a subset of it
- Not all guardrails are statically verifiable (e.g., IF-12 "no untested code" requires coverage tools, not architecture tests)
- Stack overlays provide concrete test scaffolding; the ADR defines the requirement
