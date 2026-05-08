# ADR-011: Type-Safe Value Object IDs

## Status

Accepted

## Context

Using primitive types (strings, integers, UUIDs) for entity identifiers creates a class of bugs where IDs of different entity types are accidentally swapped. A function that accepts `(customerId: string, orderId: string)` can be called with the arguments reversed, and the compiler cannot detect the error. These bugs are subtle, often pass unit tests (which may use the same test ID for both), and surface only in integration or production.

## Decision

Every entity identity is represented as a dedicated Value Object that wraps the underlying primitive, providing type safety at compile time.

### Structure

Each ID Value Object:

- Wraps a single primitive value (typically a UUID string or a long integer)
- Validates the value at construction time (non-null, non-blank, correct format)
- Is immutable after construction
- Implements equality based on the wrapped value
- Provides a `value` accessor to retrieve the underlying primitive when needed (e.g., for persistence or serialization)

### Pseudocode Example

```
class OrderId:
    constructor(value):
        if value is null or blank:
            throw "OrderId cannot be null or blank"
        this.value = value

    equals(other):
        return other is OrderId and this.value == other.value

    static generate():
        return new OrderId(newUUID())

class CustomerId:
    constructor(value):
        if value is null or blank:
            throw "CustomerId cannot be null or blank"
        this.value = value
```

With these types, `placeOrder(customerId: CustomerId, orderId: OrderId)` cannot be called with swapped arguments — the type system rejects it.

### Factory Methods

- `generate()` — Creates a new ID with a generated value (for new entities)
- Constructor — Wraps an existing value (for reconstitution from persistence)

### Usage in Store Ports

Store ports use the typed ID:

```
interface OrderStore:
    findById(id: OrderId): Optional<Order>
    save(order: Order): void
```

Not:

```
interface OrderStore:
    findById(id: String): Optional<Order>  // WRONG: any string accepted
```

## Consequences

### Positive

- Compile-time prevention of ID-swap bugs — the most common class of subtle domain errors
- Self-documenting code: method signatures make it clear which ID type is expected
- Consistent ID validation (non-null, non-blank) enforced at the Value Object level
- Enables IDE support (autocomplete, find usages) for specific ID types

### Negative

- One additional class per entity (trivial boilerplate, often generated or templated)
- Requires unwrapping when passing to infrastructure (database queries, HTTP responses)
- Teams accustomed to primitive IDs may resist the initial overhead

### Neutral

- The underlying primitive type (UUID, long, string) is an implementation detail hidden by the Value Object
- Store adapters handle wrapping/unwrapping at the infrastructure boundary
- The pattern applies to entity IDs; child entity IDs within an entity may use simpler types if they are never referenced externally
