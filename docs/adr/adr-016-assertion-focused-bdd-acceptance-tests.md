# ADR-016: Assertion-Focused BDD Acceptance Tests

Reference: *The Effective Software Engineer* (Ellersdorfer, 2026), Ch. 4, 5 — "Executable Requirements", "ATDD as Truth".

## Status

Accepted

## Context

BDD acceptance tests are the specification (ADR-003). When a single test method bundles many assertions — state changes, notifications, audit trail entries, different entity properties — three problems emerge:

1. **Failure diagnosis is ambiguous.** A test named `therapistAcceptsReferral` that asserts referral status, participant list, and notification tells you *something* broke, but not *which effect* broke. The team wastes time re-running and reading logs instead of reading the test name.
2. **Business feature scoping is blocked.** Product decisions often toggle individual effects ("we no longer notify on acceptance" or "we defer audit trail to phase 2"). When effects are bundled into one test, scoping a feature means editing test internals rather than including or excluding whole tests.
3. **Verification is confused with approval.** A test that checks five things at once reads like a checklist seeking sign-off. A test that checks one thing reads like a hypothesis being verified — which is the intent of acceptance testing.

## Decision

Each BDD acceptance test has **at most 1–2 assertions** about **one behavioral concern**.

### Splitting Rules

When a test has more than 2 assertions, split it into multiple tests. Each split test repeats the same arrange/act steps but contains only the assertions for its specific concern.

| # | Rule | Suffix Convention | Example |
|---|------|-------------------|---------|
| 1 | Notifications split from domain state | `_notification` | `therapistAcceptsReferral` + `therapistAcceptsReferral_notification` |
| 2 | Audit trail splits from domain state | `_auditTrail` | `switchScope_sharedToCustomer` + `switchScope_sharedToCustomer_auditTrail` |
| 3 | Different entity/concern assertions split | descriptive suffix | `therapistAcceptsReferral_referralAccepted` + `therapistAcceptsReferral_participantAdded` |
| 4 | Cohesive assertions (≤2 about same property) stay together | — | `assertAppointmentIsCreated` + `assertAppointmentStatusIs(SCHEDULED)` in one test |
| 5 | Rejection + state-unchanged stays together | — | `assertOperationRejected("FORBIDDEN")` + `assertStatusIs(ACTIVE)` in one test |

### Naming Convention

- Method: `originalName_suffixDescribingConcern()`
- DisplayName: `"Original description - Suffix describing concern"`

### Setup Duplication

Split tests duplicate the arrange/act steps of the original. This is expected and acceptable. The BDD DSL layer (Driver interface) absorbs setup complexity through helper methods (e.g., `setupAcceptedTherapyReferral`). The cost of duplicated setup is outweighed by the diagnostic and scoping benefits.

## Consequences

### Positive

- Failures name the exact broken effect — no ambiguity, no re-running
- Business features can be scoped by including or excluding whole test methods
- Each test reads as a single verifiable hypothesis
- Test suite becomes a browsable catalog of individual behavioral effects
- Consistent with ADR-003: tests are the specification, and each specification point is independently verifiable

### Negative

- More test methods (same total assertion coverage, more boilerplate setup)
- Requires discipline to apply consistently when writing new tests
- Existing test suites require a one-time refactoring pass

### Neutral

- Total assertion count across the suite remains unchanged — no assertions are lost or added
- The BDD 4-layer architecture (Test → DSL → Driver → SUT) is unaffected
- DSL interfaces require no changes — splits only rearrange which assertions appear in which test method
