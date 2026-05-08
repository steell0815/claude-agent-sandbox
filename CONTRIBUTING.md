# Contributing to claude-agent-sandbox

## Core Principles

- **Security is not optional** — it is a professional and ethical obligation.
- **Quality is a shared responsibility** — every contributor upholds the same standards.
- Code that weakens security, privacy, or data integrity will not be accepted.
- **Psychological safety is a prerequisite** — blameless postmortems, learning reviews, normalize "I don't know".
- **Curiosity is the default mode** — question storming, curiosity check-ins, learning reviews.

---

## Expectations for Contributions

### Code Quality

- Tests are expected (preferably TDD)
- Readability is more important than cleverness
- Code must be easy to change and reason about

### Architecture

- Respect domain boundaries
- Avoid leaking infrastructure concerns into domain logic
- Prefer explicit models over implicit behavior
- Be aware of Conway's Law: architecture mirrors communication structure

### Documentation

- Significant changes require documentation
- Domain-relevant assumptions must be documented
- Security-relevant decisions must be explained

---

## What We Will Not Accept

- Features that bypass security or authorization
- Undocumented domain assumptions
- "Temporary" hacks that become permanent
- Changes without tests (unless explicitly agreed)

---

## The Programmer's Oath

Adapted from Robert C. Martin (*The Effective Software Engineer*, Ch. 3). Internal contributors commit to the following:

1. **I will not produce harmful code.** I will not knowingly write code that damages users, data, or systems.
2. **I will always produce my best work.** I will not knowingly release code that is defective in behavior or structure.
3. **I will produce repeatable proof that my code works.** Every change has tests that can be run at any time to verify correctness.
4. **I will make frequent, small releases.** I will not build up large batches of changes that delay feedback and increase risk.
5. **I will fearlessly improve the codebase.** I will not let fear of breaking something prevent necessary refactoring.
6. **I will protect productivity.** I will not do anything that decreases the team's ability to deliver value.
7. **I will cover for my teammates.** I will learn their work well enough to help when needed and ensure no one is a single point of failure.
8. **I will give honest estimates.** I will not make promises I cannot keep. When I don't know, I will say so.
9. **I will never stop learning.** I will continuously improve my skills and share what I learn with my team.

---

## Legal & Licensing

All contributions must be compatible with the project license.

By submitting a contribution, you agree that:
- You have the right to submit the work
- You grant the project the right to distribute it under the project license

---

## How to Contribute

1. Open an issue to discuss significant changes
2. Fork the repository
3. Work in small, reviewable increments
4. Provide tests and documentation
5. Submit a pull request

---

## Internal Development (Trunk-Based, Direct-to-Main)

This project uses **Trunk-Based Development** with **Continuous Integration**.

For internal contributors, the default workflow is:

- Work in small, reviewable increments
- Integrate to trunk at minimum daily (commit early, commit often)
- Push **directly to `main`**
- No long-lived feature branches
- No pull requests for internal changes (unless explicitly agreed for exceptional cases)
- Prefer pair or ensemble programming as primary review mechanism (see [ADR-002](docs/adr/adr-002-pair-programming-as-default-review.md))

This approach optimizes for fast feedback, high integration frequency, and reduced merge risk.

### Working Agreements

Internal contributors agree to:

- Keep changes small (preferably minutes to a few hours of work)
- Keep `main` green (treat breakages as top priority)
- Write tests as part of the work (ideally via TDD)
- Prefer readability and changeability over cleverness
- Treat security and privacy as first-class engineering constraints
- Optimize for flow, not utilization
- Maintain sustainable pace
- Acceptance tests are the specification (see [ADR-003](docs/adr/adr-003-atdd-as-specification-method.md))
- Decompose work into vertical slices (see [ADR-005](docs/adr/adr-005-vertical-slicing-as-work-decomposition.md))

---

## Main Branch Protection Contract (Internal)

`main` is the only long-lived branch and represents the current integrated state.

By pushing to `main`, internal contributors agree to the following contract:

- **`main` must stay releasable.**
  Every commit should keep the system in a working state.

- **Fast feedback is mandatory.**
  The CI *commit stage* must run for every push and must stay green.

- **If you break `main`, you stop and fix it.**
  Repairing `main` takes priority over starting new work.

- **Small, reversible changes.**
  Prefer small commits and incremental design. Use feature toggles when needed rather than long-lived branches.

- **Acceptance is part of "done".**
  If a change impacts end-to-end behavior, acceptance tests must be updated and must pass in the acceptance stage.

- **Security signals are release signals.**
  SAST/DAST findings are treated as engineering outcomes, not "nice-to-have" reports.

- **Traceability over heroics.**
  Meaningful commit messages, reproducible builds, and documented decisions are expected.

- **Pipeline is the only deployment path.**
  No manual deployments. All changes reach production exclusively through the CI/CD pipeline.

---

## Continuous Integration Pipeline

Every commit to `main` triggers a multi-stage verification pipeline.

### 1) Commit Stage (Fast Verification)

The commit stage validates the commit quickly and deterministically, including:

- Build + unit tests
- Static checks / formatting / linting (as configured)
- **SAST** (Static Application Security Testing)

A commit is considered acceptable only if the commit stage passes.

### 2) Acceptance Stage (BDD Acceptance Tests)

The acceptance stage runs **BDD-style acceptance tests** that are explicitly marked as longer-running.

Conventions:

- Acceptance tests are tagged/organized in dedicated directories
- Only acceptance tests are executed in this stage

The acceptance stage produces a reportable outcome (test results are treated as a first-class delivery signal).

> Acceptance tests are the executable definition of system behavior across layers
> (Test → DSL → Driver → System Under Test).

---

## Delivery Standard (Minimum CD)

This project adopts the [Minimum CD](https://minimumcd.org) standard as its delivery baseline (see [ADR-001](docs/adr/adr-001-adopt-minimum-cd.md)).

### Single Path to Production

The CI/CD pipeline is the **only** method for deploying to production. No manual deployments, no SSH-and-copy, no "just this once" exceptions. If it didn't go through the pipeline, it doesn't go to production.

### Deterministic Pipeline

The pipeline verdict is definitive. If the pipeline fails, the change is not deployable — no human override, no "it works on my machine" exceptions. Pipeline results are trusted and acted upon.

### Definition of Deployable

An artifact is deployable only when **all** of the following gates pass:

- Build succeeds
- Unit tests pass
- Lint and formatting checks pass
- Type checking passes
- SAST scan reports no blocking findings
- SBOM generated (CycloneDX)
- Acceptance tests pass in a production-like environment

### Immutable Artifacts

Once the pipeline produces an artifact, it must not be modified. The same artifact that passes the pipeline is the artifact that is deployed. Artifacts are tagged with the git SHA that produced them.

### Production-Like Test Environment

Acceptance tests run in an environment that matches production in all material aspects (OS, runtime versions, backing services, network topology). Differences between test and production environments are documented and minimized.

### On-Demand Rollback

Every deployment must support immediate rollback to the previous known-good state. The rollback mechanism is deployment-specific (e.g., Helm rollback, blue-green swap, container image revert) but the capability is non-negotiable.

### Application Configuration

Configuration is externalized and deploys alongside the artifact via environment variables or config maps. No environment-specific values (URLs, credentials, ports, feature flags) are baked into build artifacts.

### Daily Minimum Integration

All contributors integrate to trunk at minimum once per day. If work is not ready, commit with a `WIP:` prefix. Long-lived branches and deferred integration are not acceptable.

---

## When to Use PRs Internally (Exception)

Internal pull requests may be used when:
- a change is unusually risky or wide-reaching
- compliance/legal review is required
- an external partner contributes to internal branches
- the team explicitly agrees that review gates outweigh integration speed for that change
