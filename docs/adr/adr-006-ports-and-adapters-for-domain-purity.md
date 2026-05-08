# ADR-006: Ports and Adapters for Domain Purity

Reference: *The Effective Software Engineer* (Ellersdorfer, 2026), Ch. 3 — "DIP", "Ports & Adapters in one minute", "Guiding questions".

## Status

Accepted

## Context

Domain logic that depends directly on infrastructure (databases, HTTP frameworks, message brokers, file systems) becomes difficult to test, difficult to change, and tightly coupled to technology choices. When the domain imports a framework, replacing or upgrading that framework requires rewriting business logic.

The Ports and Adapters (Hexagonal) architecture enforces a strict dependency direction: the domain defines interfaces (ports) that describe what it needs, and infrastructure code implements those interfaces (adapters) outside the domain boundary.

## Decision

The domain layer defines ports (interfaces); adapters implement them outside the domain.

- **Ports** are interfaces owned by the domain that describe capabilities the domain requires (e.g., repository interfaces, notification ports, event publishers).
- **Adapters** are implementations of those ports that live outside the domain boundary (e.g., database repositories, HTTP clients, message queue publishers).
- The domain has **zero dependencies** on infrastructure frameworks. No framework imports, no ORM annotations, no HTTP-specific types inside the domain.
- **Domain tests run without database, network, or framework.** The BDD Domain Driver validates this constraint — if a domain test requires infrastructure to run, the architecture is violated.

## Consequences

### Positive

- Domain logic is testable in isolation — fast, deterministic, no infrastructure setup
- Technology choices (database, framework, messaging) can change without modifying domain code
- Forces explicit contracts between domain and infrastructure via interfaces
- BDD Domain Driver serves as a continuous architectural fitness function

### Negative

- Requires discipline to define ports before implementing adapters
- More interfaces and adapter classes than a direct-dependency approach
- Developers unfamiliar with the pattern may place infrastructure concerns in the domain initially

### Neutral

- Does not prescribe how adapters are wired to ports (dependency injection framework, manual wiring, etc.)
- The pattern applies at the bounded context level — different contexts may have different adapter implementations
