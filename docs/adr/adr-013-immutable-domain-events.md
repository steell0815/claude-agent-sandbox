# ADR-013: Immutable Domain Events (Cause + Effect)

## Status

Accepted

## Context

Domain events represent facts about the system — both what is being requested and what has happened. They are consumed by other parts of the system (event handlers, projections, audit logs, external integrations) that depend on their structure and content. If events can be mutated after creation, or if their structure changes without versioning, consumers break silently.

Additionally, a complete event model needs to capture both sides of an interaction: the input (what was requested) and the output (what happened as a result). This bidirectional traceability is essential for debugging, auditing, and understanding system behavior.

## Decision

All domain events are immutable records following a **Cause + Effect** model. Events live in a separate module from entities.

### Cause Events (Input)

Causes represent what is being requested. They are designed **outside-in** — starting from the external trigger and working toward the domain.

- Named imperatively: `PlaceOrder`, `SubmitActor`, `CancelInvoice`
- Represent the intent of the caller
- Carry the data needed to execute the request
- Immutable after construction

### Effect Events (Output)

Effects represent what happened as a result. They are designed **inside-out** — starting from the domain state change and working toward consumers.

- Named in past tense: `OrderPlaced`, `ActorSubmitted`, `InvoiceCancelled`
- Represent facts that already occurred
- Carry the data consumers need to react
- Immutable after construction

### Properties of All Domain Events

1. **Immutable** — All fields are set at construction time and cannot be modified afterward. Use language-appropriate immutability mechanisms (records, readonly properties, frozen objects, final fields).

2. **Self-contained** — Events carry all the data consumers need to process them. Consumers should not need to query back to the entity for additional context.

3. **Minimal** — Events contain only the data relevant to what happened, not the entire entity state. Include IDs, changed values, and context — not every field of the entity.

4. **Versioned** — Once published, an event's structure is a contract. If the structure needs to change, create a new version of the event rather than modifying the existing one.

### Pseudocode Example

```
// Cause event (input — what is requested)
record PlaceOrder:
    customerId: CustomerId
    items: List<OrderItem>
    requestedAt: Timestamp

// Effect event (output — what happened)
record OrderPlaced:
    orderId: OrderId
    customerId: CustomerId
    items: List<OrderItem>
    totalAmount: Money
    occurredAt: Timestamp
```

### Event Module Structure

Events live in a separate module from entities:

```
events/
  cause/
    PlaceOrder.{ext}
    SubmitActor.{ext}
  effect/
    OrderPlaced.{ext}
    ActorSubmitted.{ext}
```

### Event Publishing Rules

- Interactors/use cases publish effect events after successful execution
- Effects are published **after the transaction commits** — if the transaction rolls back, no events are published
- The event publisher is called by the interactor, not by the entity itself
- Consumers must be **idempotent** — events may be delivered more than once (at-least-once delivery)

### Event Versioning

When an event's structure must change:

```
// Original event (never modified)
record OrderPlaced_V1:
    orderId: OrderId
    customerId: CustomerId
    items: List<OrderItem>

// New version with additional data
record OrderPlaced_V2:
    orderId: OrderId
    customerId: CustomerId
    items: List<OrderItem>
    totalAmount: Money
    shippingAddress: Address
```

Consumers must handle both versions during the migration period.

## Consequences

### Positive

- Events are safe to share across threads, processes, and systems — immutability eliminates concurrency hazards
- Event consumers can rely on stable contracts — no silent structural changes
- Cause + Effect pairs provide complete bidirectional traceability
- Causes designed outside-in align with user intent; Effects designed inside-out align with domain behavior
- Audit trails capture both what was requested and what resulted
- Versioning enables schema evolution without breaking existing consumers

### Negative

- Immutability requires creating new instances for any derived data, which may feel verbose in some languages
- Event versioning adds complexity when many versions coexist
- Maintaining both cause and effect events requires more event types than an effect-only model
- Separate events module adds a build dependency

### Neutral

- The specific immutability mechanism depends on the language (Java records, TypeScript readonly, Kotlin data class)
- Event storage (if using event sourcing) and event publishing (if using messaging) are infrastructure concerns, not domain concerns
- The interactor publishes events; the application layer provides the publishing infrastructure — this separation is consistent with Clean Architecture (ADR-008)

