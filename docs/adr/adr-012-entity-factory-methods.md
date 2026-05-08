# ADR-012: Entity Construction and Modification

## Status

Accepted

## Context

Entities need clear patterns for construction (creating new instances) and modification (changing state). The construction pattern must support two contexts:

1. **Creating a new instance** — The entity is being created for the first time. Business rules must be validated, initial state must be set, and a domain event (e.g., `OrderPlaced`) should be published.

2. **Reconstituting from persistence** — The entity is being loaded from the database. The data has already been validated (it was valid when it was saved).

Additionally, domain entities are immutable — state changes produce new instances rather than mutating existing ones. The modification pattern must support this immutability.

## Decision

We adopt the Builder pattern as the primary approach for entity construction and modification.

### Construction — Builder Pattern

Entities use a fluent builder for construction:

```
// Creating a new entity
order = Order.builder()
    .id(OrderId.generate())
    .customerId(customerId)
    .items(items)
    .status(PENDING)
    .createdAt(now())
    .build()
```

The `build()` method validates all business invariants before returning the instance. Invalid state is rejected at construction time.

### Modification — toBuilder Pattern

Since entities are immutable, state changes produce new instances via `toBuilder()`:

```
// Modifying an entity (produces a new instance)
updatedOrder = order.toBuilder()
    .status(SHIPPED)
    .shippedAt(now())
    .build()
```

This preserves immutability while providing a fluent API for state transitions.

### Pseudocode Example

```
class Order:
    // Builder with validation
    @Builder(toBuilder = true)

    static placeOrder(customerId, items):
        if items is empty:
            throw "Order must have at least one item"

        order = Order.builder()
            .id(OrderId.generate())
            .customerId(customerId)
            .items(items)
            .status(PENDING)
            .createdAt(now())
            .build()

        order.registerEvent(OrderPlaced(order.id, customerId, items))
        return order

    ship():
        if this.status != CONFIRMED:
            throw "Only confirmed orders can be shipped"

        return this.toBuilder()
            .status(SHIPPED)
            .shippedAt(now())
            .build()
```

### Reconstitution from Persistence

When loading entities from the database, the builder is used directly without re-running business validation — the data was valid when it was saved:

```
class OrderStoreAdapter implements OrderStore:
    toDomain(record):
        return Order.builder()
            .id(OrderId(record.id))
            .customerId(CustomerId(record.customerId))
            .items(mapItems(record.items))
            .status(record.status)
            .createdAt(record.createdAt)
            .build()
```

When entities serialize directly (e.g., via Jackson), no explicit reconstitution logic is needed.

## Consequences

### Positive

- Fluent, readable construction API
- Immutability preserved — modifications produce new instances via `toBuilder()`
- Single pattern serves both new creation and persistence reconstitution
- No separate `reconstitute` method to maintain alongside `create`
- Language-native support in many stacks (Lombok `@Builder`, Kotlin `copy()`, TypeScript spread)

### Negative

- Builder validation must be explicit (the builder itself doesn't enforce invariants without custom logic)
- Developers must use `toBuilder()` for modifications, not direct field access
- Some languages require boilerplate for builder support

### Alternatives Considered

**Factory Methods (create + reconstitute)** — Two static factory methods: `create()` for new instances with full validation and event publishing, `reconstitute()` for persistence loading without re-validation. This approach provides clearer semantic separation but adds boilerplate and requires maintaining two construction paths.

### Neutral

- The specific builder implementation depends on the language and stack overlay
- Value objects follow the same builder pattern when they have multiple fields; simple value objects may use direct constructors
- The pattern applies to entities; child entities created within an entity use the entity's methods
