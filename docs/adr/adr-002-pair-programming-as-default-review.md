# ADR-002: Pair Programming as Default Review

Reference: *The Effective Software Engineer* (Ellersdorfer, 2026), Ch. 4 — "Why Pairing Wins (Always)", TBD needs synchronous thinking.

## Status

Accepted

## Context

Trunk-based development with continuous integration requires fast feedback on code quality. Traditional async pull-request review introduces latency between writing and reviewing, encourages large batches, and delays integration — all of which undermine CI.

Pair programming and ensemble (mob) programming provide real-time review as code is written. The feedback loop is immediate, knowledge spreads across the team, and the need for after-the-fact review disappears.

## Decision

Pair or ensemble programming is the preferred review mechanism for all internal trunk-based development. Code produced through pairing is considered reviewed and may be pushed directly to `main`.

Async pull-request review is the exception, reserved for cases documented in CONTRIBUTING.md (unusually risky changes, compliance requirements, external contributors, or explicit team agreement).

## Consequences

### Positive

- Review happens during authoring, not after — faster feedback, fewer defects
- Knowledge spreads continuously across the team
- Eliminates PR review latency, supporting daily (or more frequent) integration
- Reduces the "bus factor" for any given area of the codebase

### Negative

- Requires overlapping working hours for pair/ensemble sessions
- May feel slower for experienced developers accustomed to solo work
- Needs deliberate facilitation to avoid driver/navigator imbalance

### Neutral

- Does not eliminate the PR mechanism — it remains available for exceptional cases
- Pairing tools (Live Share, tmux, etc.) are team-specific and not prescribed here
