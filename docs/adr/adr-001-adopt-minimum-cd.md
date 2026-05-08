# ADR-001: Adopt Minimum CD as Delivery Standard

## Status

Accepted

## Context

The project already practices trunk-based development, red pipeline protocol, a two-stage CI pipeline (commit + acceptance), TDD/BDD, and small batches. However, several principles from the Minimum CD standard (minimumcd.org) are not explicitly codified in our documentation or workflows:

1. **Single Path to Production** — the pipeline must be the only way to deploy
2. **Deterministic Pipeline** — the pipeline verdict is definitive; no human override
3. **Definition of Deployable** — a canonical list of gates that must pass before an artifact is deployable
4. **Immutable Artifacts** — artifacts must not be modified after the pipeline produces them
5. **Production-Like Test Environment** — acceptance tests must run in an environment that matches production
6. **On-Demand Rollback** — every deployment must support immediate rollback
7. **Application Configuration** — configuration deploys alongside the artifact via environment variables, not baked into builds
8. **Daily Minimum Integration** — integrate to trunk at minimum once per day

Without explicit codification, these principles exist as tribal knowledge that erodes over time, particularly as the team grows or contributors rotate.

## Decision

We adopt the Minimum CD standard (minimumcd.org) as our delivery baseline. All eight principles listed above are incorporated into our engineering practices:

- **CONTRIBUTING.md** gains a "Delivery Standard (Minimum CD)" section that documents all eight principles as working agreements.
- **CLAUDE.md** renames "Quality Gates" to "Quality Gates (Definition of Deployable)" and adds SAST and acceptance-in-production-like-environment as explicit gates.
- **Skill workflows** (`/commit`, `/push`, `/review-pr`, `/implement-feature`) are updated to enforce relevant principles at the point of action:
  - `/push` checks pipeline status before pushing
  - `/commit` reinforces daily integration and prohibits environment-specific values
  - `/review-pr` adds a delivery checklist (no hardcoded config, rollback safety, artifact immutability, no manual deploy steps)
  - `/implement-feature` adds deployment readiness checks (artifact immutability, externalized config, rollback safety)

We are deliberately **not** prescribing specific rollback tooling (Helm rollback, blue-green, canary, etc.) — the principle is codified; the mechanism is deployment-specific.

## Consequences

### Positive

- All eight Minimum CD principles are discoverable in a single ADR and referenced from working documents
- New contributors encounter these principles during onboarding through CONTRIBUTING.md
- Agent workflows enforce the principles at commit, push, and review time
- Reduces drift between stated values and actual practice

### Negative

- Adds review friction for contributors unfamiliar with Minimum CD concepts
- Requires discipline to keep acceptance test environments production-like as infrastructure evolves

### Neutral

- No new tooling is introduced; this is a documentation and workflow change
- Stack-specific implementations (e.g., Docker tagging strategy, Helm rollback) remain the responsibility of stack overlays
