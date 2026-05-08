# ADR-014: Three-Stage Deployment Pipeline

## Status

Accepted

## Context

Continuous Delivery requires a reliable, repeatable deployment pipeline that gives fast feedback on code quality and correctness. Without a defined pipeline model, teams make ad-hoc decisions about what to test and when, leading to slow feedback loops, inconsistent quality gates, and security gaps that are discovered late.

A proven pipeline model structures automated verification into stages that progressively increase confidence while keeping feedback fast.

## Decision

We adopt a three-stage deployment pipeline with continuous dependency scanning.

### Stage 1: Commit Stage (every push/PR)

The commit stage runs on every push and pull request. It provides fast feedback (target: under 5 minutes) on code quality and basic correctness.

What runs:
- Formatting verification (Prettier / Checkstyle)
- Linting and static analysis (ESLint / SonarCloud)
- Type checking
- Unit tests (entities, interactors, value objects)
- Code coverage analysis (JaCoCo / v8 — must meet threshold per circle)
- Incremental mutation testing (PiTest / Stryker — ≥ 80% killed on changed files)
- SAST scan (SonarCloud — no blocking findings)

Gate: All checks must pass. PR cannot be merged if any check fails.

### Stage 2: Acceptance Stage (after commit stage passes)

The acceptance stage runs BDD acceptance tests that prove the system behaves correctly from the user's perspective.

What runs:
- BDD acceptance tests tagged `@acceptanceTest`
- Tests run across all three drivers: domain, controller, UI
- Security acceptance tests (authentication, authorization, data isolation)
- Performance acceptance tests (bounded results, response times)
- SBOM generation (CycloneDX)

Gate: All acceptance tests must pass across all drivers.

### Stage 3: DAST Stage (daily + manual trigger)

The DAST stage runs dynamic security scanning against a running application with real infrastructure.

What runs:
- OWASP ZAP baseline scan against running application
- Scan runs with real OIDC provider / authentication infrastructure
- Vulnerability report generated and reviewed

Gate: No high-severity findings. Report reviewed by team.

### Nightly: Full Mutation Analysis

Runs on a nightly schedule for trend tracking. This is informational — it does not gate deployments.

What runs:
- Full-codebase mutation testing (PiTest / Stryker — all modules, not just changed files)
- Mutation score trend report generated and published

Purpose: Catches mutation score regressions in unchanged code over time and provides a project-wide view of test effectiveness.

### Continuous: Dependency Scanning

Runs daily and independently of the pipeline:
- Dependabot (or equivalent) scans for known vulnerabilities in dependencies
- Critical vulnerabilities block deployment until resolved

### Pipeline Flow

```
Push/PR → [Commit Stage] → [Acceptance Stage] → [Deploy]
                                                     ↑
                                    [DAST Stage] ────┘ (daily + manual)
                                    [Dependabot] ────── (daily, continuous)

Nightly → [Full Mutation Analysis] (informational, trend tracking)
```

## Consequences

### Positive

- Fast feedback: commit stage catches most issues in under 5 minutes
- Security is proven, not assumed: acceptance tests verify authentication, authorization, and data isolation across all drivers
- Performance is proven, not assumed: acceptance tests verify bounded results and response times
- DAST catches runtime vulnerabilities that static analysis misses
- Clear gates prevent unverified code from progressing

### Negative

- Three stages take longer than a single test run (mitigated by parallelism and fast commit stage)
- DAST requires a running environment with real infrastructure
- Maintaining three drivers (domain, controller, UI) for acceptance tests requires discipline

### Neutral

- The specific CI/CD tool (GitHub Actions, Jenkins, etc.) is an implementation detail
- Stage configuration is defined by the stack overlay
- The pipeline model applies per deployable artifact
