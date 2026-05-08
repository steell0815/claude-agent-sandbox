# Domain Center

The domain center contains the core business logic organized into three areas: Entities, Interactors/Use Cases, and Events. It has **zero dependencies** on frameworks, databases, HTTP, or any infrastructure concern. Domain code is pure — it can be tested without any external systems.

## Entities

### Purpose

- Define the ubiquitous language through entities, value objects, and domain services
- Enforce business invariants and rules
- Model state transitions within entities
- Declare store ports (interfaces) that the application layer implements

### Instant Failures (Entity-Specific)

| Rule | Violation Example (pseudocode) |
|------|-------------------------------|
| No framework imports | `import OrmAnnotation` in a domain entity |
| No infrastructure types | Domain method returning a `DatabaseResult` or `HttpResponse` |
| No persistence concerns | Domain entity with `save()`, `load()`, or table-mapping logic |
| No application layer references | Domain importing from `controllers` or `config` package |
| Immutable entities and VOs | Entity with public setters or mutable collections |
| No raw null returns | Store port returning `null` instead of absent-value type |

### Entity

- The only entry point for modifying the entity's state
- Enforces all invariants after every operation
- Uses the builder pattern for construction: `Entity.builder()...build()`
- Uses `toBuilder()` for immutable modifications: `entity.toBuilder().field(val).build()`
- Entities represent full application independent business rules, like Account, Order. Everything that would exist with all details. No relational idea behind an entity.
- Immutable after construction.
- Build with Entity builder, that is part of the entity.
- Modification means Entity.toBuilder().doX(x).doY(y).updateRevision().build();
- Entities may have getters, but no setters... like accountInstance.getBalance().
- Entities carry a Revision, that informs about their current version to support optimistic locking, their creation and modification timestamps, creator and modifier.

### Value Objects

- Immutable after construction
- Validated at construction time — invalid state is unrepresentable
- Equality based on attributes, not identity
- Identity VOs (`OrderId`) wrap a primitive with type safety
- Business VOs (`Money`, `EmailAddress`) encapsulate validation rules and behavior

### Store Ports

- Defined as interfaces in the entity layer (e.g., `Store<Order>` or `OrderStore`)
- The domain declares what it needs; the application layer decides how to implement it
- Return absent-value types (Optional, Maybe) for single-entity lookups
- Never return raw nulls
- Expose specific query methods, not generic CRUD

### Domain Services

- Contain logic that doesn't naturally belong to a single entity
- Stateless — all state is in entities and value objects
- Used sparingly — most logic belongs in entities or value objects

## Interactors / Use Cases

### Purpose

- Contain application-specific business rules (not just orchestration)
- Each use case is its own class: `{Verb}{Noun}UseCase`
- Interactor facades group related use cases: `{Entity}Interactor`
- Depend only on Entities (store ports, entities, value objects)

### Use Case Pattern

```
class PlaceOrderUseCase:
    constructor(orderStore, eventPublisher):
        this.orderStore = orderStore
        this.eventPublisher = eventPublisher

    execute(request):
        order = Order.builder()
            .id(OrderId.generate())
            .customerId(request.customerId)
            .items(request.items)
            .status(PENDING)
            .build()

        orderStore.save(order)
        eventPublisher.publish(OrderPlaced(order.id, request.customerId))
        return OrderResponse.from(order)
```

### Interactor Facade Pattern

```
class OrderInteractor:
    constructor(placeOrderUseCase, cancelOrderUseCase, shipOrderUseCase):
        // Delegates to individual use cases

    placeOrder(request):
        return placeOrderUseCase.execute(request)

    cancelOrder(request):
        return cancelOrderUseCase.execute(request)
```

## Events

### Purpose

- Define Cause + Effect event pairs in a separate module
- Causes: imperative input events designed outside-in (`PlaceOrder`, `SubmitActor`)
- Effects: past-tense output events designed inside-out (`OrderPlaced`, `ActorSubmitted`)
- Immutable records — once created, never modified
- Versioned — never modify an existing event's structure; create a new version

## Package Structure (Abstract)

```
domain/
  entity/                         # Entities, VOs
    {Entity}.{ext}
    {Entity}Id.{ext}
    {ValueObject}.{ext}
  usecase/                        # Use cases
    {Verb}{Noun}UseCase.{ext}
  interactor/                     # Facade + value objects
    {Entity}Interactor.{ext}
    valueobjects/
  adapter/                        # Port interfaces (Store<T>)
    {Entity}Store.{ext}
  model/                          # Request/Response models
    {Verb}{Noun}Request.{ext}
    {Noun}Response.{ext}

events/                           # Separate module
  cause/
    {Verb}{Entity}.{ext}
  effect/
    {Entity}{PastTenseVerb}.{ext}
```

Shared value objects (e.g., `Money`, `EmailAddress`) may live in a `shared/` or `common/` directory within the domain.

## Dependency Rules

```
Entities depend on: NOTHING
Interactors depend on: Entities
Events depend on: Entities (shared types only)
Everything else depends on: Domain center
```

The domain center is the innermost circle. It defines interfaces (ports) and the rest of the system implements them. If you need to import something from outside the domain to make domain code work, the architecture is violated.

## Testing

Domain tests are unit tests that run without any infrastructure:

- No database connections
- No HTTP servers
- No framework bootstrapping
- No file system access

Interactor tests use **InMemoryTestStore** implementations (not mocks) to verify business logic with realistic store behavior.

If a domain test requires infrastructure to run, the domain center has a leaked dependency. The BDD Domain Driver validates this constraint continuously.
