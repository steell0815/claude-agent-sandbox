# ADR-007: Prototypes as Evolvable First Versions

Reference: *The Effective Software Engineer* (Ellersdorfer, 2026), Ch. 5 — "The Myth of the Throwaway Prototype", "The Minimal Reliable Slice".

## Status

Accepted

## Context

The "throwaway prototype" is a persistent myth in software development. In practice, prototypes rarely get thrown away. They accumulate users, dependencies, and expectations. Code written without standards because "we'll rewrite it later" becomes the production system through organizational inertia.

The cost of a prototype built to lower standards is paid twice: once to build it, and again to either rewrite it (which rarely happens) or to live with its deficiencies indefinitely.

## Decision

Prototypes are first versions, not throwaway experiments.

- All prototypes follow the same coding standards as production code (TDD, clean boundaries, meaningful names).
- Prototypes may use **simplified scope** (fewer features, reduced edge-case handling) but not **reduced quality** (no tests, no structure, no standards).
- Prototypes must have clean module boundaries so they are evolve-or-delete-ready. If a prototype proves the wrong direction, it can be cleanly removed. If it proves the right direction, it can be evolved without rewriting.
- "Fail fast" means learning quickly through disciplined experimentation, not building sloppy code under time pressure.

## Consequences

### Positive

- Eliminates the "temporary code that becomes permanent" problem
- Every prototype is a candidate for evolution into the production system
- Clean boundaries ensure prototypes can be deleted without collateral damage if the experiment fails
- Maintains consistent code quality across the entire codebase

### Negative

- Initial prototyping velocity may feel slower compared to no-standards hacking
- Requires discipline to resist "just this once" shortcuts under deadline pressure

### Neutral

- Does not prohibit time-boxed exploration (spikes) — but spikes produce decisions and learning, not production code
- The distinction is between reduced scope (acceptable) and reduced quality (not acceptable)
