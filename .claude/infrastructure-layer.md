# Adapters Reference

This document provides reference patterns for store implementations and external service integrations. In Clean Architecture, adapters live in the application (execution environment) layer — they are plugins that connect the domain center to external systems.

## Store Adapters

Store adapters implement the store ports (interfaces) defined in the domain center. They handle persistence, translating between domain entities and database representations.

### Implementation Pattern

```
class OrderStoreAdapter implements OrderStore:
    function findById(orderId):
        record = techStore.findById(orderId.value)
        return record.map(r => toDomain(r))

    function save(order):
        record = toPersistence(order)
        techStore.save(record)
```

### Instant Failures

| Rule | Violation Example (pseudocode) |
|------|-------------------------------|
| No query string concatenation | `"SELECT * FROM orders WHERE id = " + id` |
| No in-memory filtering of unbounded datasets | `store.findAll().filter(x => x.status == active)` |
| No in-memory sequence generation | `static counter = 0; counter++` for IDs |
| No persistence model exposure beyond adapter | Returning `OrderEntity` from store adapter |
| No missing migrations for schema changes | Adding a column in code without a migration script |
| No business logic in stores | `if order.total > threshold` inside a store method |

### Technology Stores

Technology-specific store implementations (JPA, Prisma, Knex, etc.) are wrapped by store adapters:

```
store/
  {Entity}StoreAdapter.{ext}           # Implements domain store port
  {Entity}{Tech}Store.{ext}           # Technology-specific store
```

### Persistence Models (Optional)

Separate persistence models are **not always required**. Entities may serialize directly (e.g., via Jackson, Prisma, or similar).

Use separate persistence models when:
- The database schema diverges significantly from the domain model
- ORM annotations or decorators would pollute the domain entity
- Complex mapping logic is needed between domain and database representations

When persistence models are used:

```
store/
  {Entity}Record.{ext}                  # Persistence model (DB representation)
  {Entity}PersistenceMapper.{ext}      # Maps domain <-> persistence model
```

### Persistence Mapping (When Applicable)

When a separate persistence model exists, every field must be mapped explicitly in both directions:

- `toDomain(persistenceModel)` → domain entity (using the builder pattern)
- `toPersistence(domainEntity)` → persistence model

When adding a new field, update **both** mapping directions. Partial mapping is an instant failure (IF-11).

### Database Migrations

- Every schema change requires a migration script
- Migrations are versioned and ordered (never modify an existing migration)
- Migrations must be backwards-compatible when possible (add columns as nullable, then backfill)
- Destructive migrations (drop column, drop table) require explicit review
- Migration scripts are tested as part of the integration test suite

### Sequence Generation

- Use database-native sequences or distributed ID generators
- Never use in-memory counters in production (they reset on application restart)
- ID generation strategy is encapsulated in the store adapter

## External Service Adapters

External integrations follow the same port/adapter pattern:

```
external/
  {Service}Adapter.{ext}               # Implements domain port for external service
```

- Port (interface) defined in the domain center
- Adapter implementation in the application layer
- Handle success, failure, and timeout scenarios
- Use circuit breakers for unreliable services

## Dependency Rules

```
Adapters depend on: Entities (for domain types and store ports)
Adapters do not depend on: Interactors (directly), Events (directly)
```

Adapters implement domain ports and translate between domain types and external representations.

## Testing

Adapter tests are **integration tests** that verify:

- Store queries return correct results with real database
- Persistence mappers correctly translate domain <-> persistence in both directions (when applicable)
- Migrations apply cleanly and produce the expected schema
- External service adapters handle success, failure, and timeout scenarios

Use test containers or embedded databases for store tests. These tests are slower than unit tests and run in the integration test phase.
