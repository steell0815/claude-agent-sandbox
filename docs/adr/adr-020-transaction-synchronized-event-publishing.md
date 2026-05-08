# ADR-020: Transaction-Synchronized Event Publishing

## Status

Proposed

## Context

ADR-013 establishes immutable domain events as Cause + Effect pairs and GR-12 requires that significant domain interactions publish events. However, neither specifies WHEN events should be published relative to the persistence transaction.

Publishing events before the transaction commits creates a consistency gap:

- **Premature publication**: Subscribers receive events for changes that may roll back, leading to phantom state in downstream systems
- **Lost events on failure**: If the application crashes between event publication and transaction commit, the event is delivered but the state change is lost
- **Ordering violations**: Events published mid-transaction may arrive at subscribers before the persisted state is queryable

This is a well-known distributed systems concern. The pattern of buffering events during the unit of work and publishing only after commit is established in DDD literature (Vernon, Evans) and implemented across frameworks (Spring's `@TransactionalEventListener`, .NET's `INotificationHandler` with `TransactionScope`, Node.js manual commit hooks).

## Decision

Domain events MUST be buffered during the unit of work and published ONLY after the persistence transaction commits successfully. Events from rolled-back transactions are discarded silently.

### Publication Rules

| Timing | Behavior |
|--------|----------|
| During transaction | Events are collected in a buffer (thread-local, async-local, or request-scoped) |
| After commit | All buffered events are published to subscribers/event bus |
| After rollback | All buffered events are discarded |
| Outside transaction | Events publish immediately (for non-transactional contexts) |

### Architectural Placement

Event buffering and publication timing is an **application layer** concern:

- The domain center raises events by adding them to a collection (e.g., `entity.domainEvents()`)
- The application layer (unit of work, transaction manager, or middleware) collects and holds events
- After the transaction commits, the application layer publishes collected events to the event dispatcher

The domain center remains unaware of transaction boundaries, preserving domain purity per IF-01 and ADR-006.

### Testing

- **Unit tests**: Verify entities raise expected events (inspect the events collection)
- **Integration tests**: Verify events are published after commit and discarded after rollback
- **Acceptance tests**: Verify downstream effects (e.g., real-time notifications) occur only after successful persistence

## Consequences

### Positive

- Eliminates phantom events from rolled-back transactions
- Subscribers can safely query persisted state when handling events
- Aligns with established DDD event publishing patterns
- Domain center remains pure — transaction awareness lives in the application layer

### Negative

- Events are slightly delayed (published after commit, not during execution)
- Requires infrastructure support per stack (transaction hooks, async-local storage)
- If the application crashes between commit and event publication, events may be lost (acceptable for most use cases; outbox pattern addresses this for critical events)

### Neutral

- This ADR complements ADR-013 (event structure) with publication timing
- The outbox pattern (persisting events in the same transaction, publishing asynchronously) is a stricter alternative for mission-critical events — this ADR does not mandate it but is compatible with it
- Stack overlays provide concrete buffering mechanisms
