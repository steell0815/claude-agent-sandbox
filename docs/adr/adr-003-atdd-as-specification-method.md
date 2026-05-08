# ADR-003: ATDD as Specification Method

Reference: *The Effective Software Engineer* (Ellersdorfer, 2026), Ch. 1, 4, 5 — "ATDD as Truth", "Executable Requirements".

## Status

Accepted

## Context

Traditional software projects maintain separate specification documents (Word files, wiki pages, Confluence spaces) that drift from the actual system behavior. Developers implement from stale specs, testers verify against different assumptions, and product owners sign off on documents that no longer reflect reality.

Acceptance Test-Driven Development (ATDD) eliminates this drift by making the acceptance tests themselves the specification. User stories serve as conversation starters to derive acceptance criteria, but the executable tests are the source of truth for expected behavior.

## Decision

Acceptance tests are the specification. There are no separate "requirements documents" or "functional specifications" outside of the executable test suite.

- User stories are conversation starters, not contracts. They exist to facilitate discussion and derive acceptance criteria.
- Acceptance tests are the source of truth for expected system behavior.
- When confused about what the system should do, read the acceptance tests.
- New behavior is specified by writing a failing acceptance test before implementation.
- Changes to behavior require updating the corresponding acceptance tests first.

## Consequences

### Positive

- Specifications are always in sync with system behavior — they execute and fail when violated
- Eliminates the cost of maintaining separate documentation that drifts
- Forces precise, unambiguous expression of requirements (code cannot be vague)
- Provides a living, executable definition of "done" for every feature

### Negative

- Requires investment in the BDD test infrastructure (DSL, drivers, fixtures)
- Non-technical stakeholders may need support to read acceptance tests as specifications
- Initial test authoring is slower than writing a prose specification

### Neutral

- User stories remain valuable as collaboration tools — their role is redefined, not eliminated
- The BDD 4-layer architecture (Test, DSL, Driver, SUT) supports this by separating intent from mechanics
