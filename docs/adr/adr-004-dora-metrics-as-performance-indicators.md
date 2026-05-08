# ADR-004: DORA Metrics as Performance Indicators

Reference: *The Effective Software Engineer* (Ellersdorfer, 2026), Ch. 7, 9 — DORA vs Traditional Metrics table, "Metrics as Mirrors, Not Weapons".

## Status

Accepted

## Context

Many teams measure performance using story points, velocity, lines of code, or individual utilization. These metrics incentivize local optimization (keeping people busy) rather than global outcomes (delivering value). Story points measure estimation accuracy at best and become gaming targets at worst. Utilization metrics drive teams toward 100% capacity, which destroys flow and eliminates slack needed for improvement.

The DORA (DevOps Research and Assessment) metrics — validated through years of research by the DORA team — directly correlate with both delivery performance and organizational outcomes.

## Decision

The primary performance indicators for this project are the four DORA metrics:

1. **Deployment Frequency** — How often code is deployed to production.
2. **Lead Time for Changes** — Time from commit to production.
3. **Change Failure Rate** — Percentage of deployments causing a failure in production.
4. **Mean Time to Restore (MTTR)** — Time to recover from a production failure.

Additionally:

- **Team morale** is tracked as a supplementary health signal (e.g., through regular retrospectives and team health checks).
- **Story points and velocity are not performance measures.** They are planning tools at best and must never be used to evaluate team or individual performance.
- **Utilization metrics are rejected.** Optimizing for utilization destroys flow. We optimize for throughput and lead time instead.

## Consequences

### Positive

- Metrics align with delivery outcomes that matter to users and the business
- Discourages gaming behaviors associated with story points and velocity tracking
- Encourages practices that improve flow: small batches, fast feedback, automation
- Team morale as a signal prevents purely mechanical optimization

### Negative

- Requires instrumentation to measure deployment frequency, lead time, and MTTR
- Teams accustomed to velocity-based planning need to adopt alternative forecasting methods
- DORA metrics measure team-level outcomes; individual contribution is intentionally not isolated

### Neutral

- Story points may still be used for relative sizing during planning — they are simply not treated as performance indicators
- The specific tooling for capturing DORA metrics is not prescribed by this decision
