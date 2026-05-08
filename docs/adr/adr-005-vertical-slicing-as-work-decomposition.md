# ADR-005: Vertical Slicing as Work Decomposition

Reference: *The Effective Software Engineer* (Ellersdorfer, 2026), Ch. 5 — "Vertical vs. Horizontal Slices", SPIDR.

## Status

Accepted

## Context

Work decomposed by technical layer (e.g., "build the database schema", "create the API endpoints", "implement the UI") delays feedback, creates integration risk, and prevents incremental delivery of user-visible value. A horizontal slice cannot be demonstrated, tested end-to-end, or shipped independently.

Vertical slicing decomposes work so that each item cuts through all necessary layers (UI, logic, data) and delivers a thin but complete piece of user-visible behavior.

## Decision

All work items are decomposed as vertical slices that deliver user-visible working behavior.

- Each slice cuts through all necessary layers: UI, application logic, domain, and data.
- Horizontal "layer-only" tasks (e.g., "set up the database", "build the API") are not permitted as standalone work items. They are embedded within the vertical slice that needs them.
- Use techniques like SPIDR (Spike, Paths, Interfaces, Data, Rules) to split stories that seem too large.
- Each slice is independently testable with acceptance tests and potentially deployable.

## Consequences

### Positive

- Every completed work item delivers demonstrable, user-visible value
- Enables continuous feedback from stakeholders on working behavior
- Reduces integration risk — layers are integrated within each slice, not deferred
- Supports trunk-based development by keeping changes small and independently valuable

### Negative

- Requires more upfront thinking to decompose work vertically
- Some infrastructure work genuinely precedes feature slices (handle via time-boxed spikes)
- Developers accustomed to layer-by-layer work may find the transition uncomfortable

### Neutral

- SPIDR and other splitting techniques are recommended but not mandated — the constraint is on the shape of the output (vertical), not the splitting method
- Spike work items are permitted for time-boxed exploration but must produce a decision, not production code
