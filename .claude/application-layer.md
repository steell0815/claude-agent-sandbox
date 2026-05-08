# Application Layer (Execution Environment)

The application layer is the execution environment — the outermost circle of Clean Architecture. It is NOT an orchestration layer. It is where the system is assembled, configured, and run. Business logic lives in the domain center (entities and interactors); the application layer provides the plugins that connect the domain to the outside world.

## Purpose

- Framework configuration (Spring config, Express setup)
- Dependency injection wiring (connecting store ports to store implementations)
- Controllers (HTTP endpoints — these are plugins)
- Store adapter implementations (connecting domain ports to databases)
- External service adapter implementations (email, messaging, file storage)

## What Does NOT Belong Here

- Business logic (belongs in entities and interactors)
- Use case orchestration (belongs in interactors)
- Request/response models (belong in domain/model or with interactors)
- Domain events (belong in events module)

## Instant Failures (Application-Specific)

| Rule | Violation Example (pseudocode) |
|------|-------------------------------|
| No business logic in controllers or adapters | `if order.total > 1000 then applyDiscount()` in a controller |
| No domain entity exposure as API response | Returning an `Order` entity directly without explicit contract consideration |
| No bypassing interactors | Controller calling store port directly instead of going through interactor |

## Package Structure (Abstract)

```
app/
  config/                          # DI wiring, framework config
    DependencyConfig.{ext}
  controller/                      # HTTP endpoints (plugins)
    {Entity}Controller.{ext}
  store/                           # Store implementations (adapters)
    {Entity}StoreAdapter.{ext}
    {Entity}{Tech}Store.{ext}
    migration/
      V{NNN}_{description}.{ext}
  external/                        # External service adapters
    {Service}Adapter.{ext}
```

## Controllers

Controllers are thin plugins: receive request, call interactor, return response.

```
function placeOrder(request):
    response = orderInteractor.placeOrder(request)
    return response
```

- No business logic — not even simple conditionals based on business rules
- All endpoints use a consistent API prefix (e.g., `/api/v1/{resource}`)
- List endpoints return bounded result sets (see GR-11 and GR-15)

## Store Adapters

Store adapters implement the store ports defined in the domain center:

```
class OrderStoreAdapter implements OrderStore:
    function findById(orderId):
        record = techStore.findById(orderId.value)
        return record.map(r => toDomain(r))

    function save(order):
        record = toPersistence(order)
        techStore.save(record)
```

- Translate between domain entities and persistence representation
- All filtering, sorting, and searching happens at the database level via queries
- Return domain entities (via mapping), never persistence models
- Support paginated queries natively

### Persistence Models (Optional)

Separate persistence models are **optional**. Use them when:

- The database representation diverges significantly from the domain model
- ORM annotations would pollute the domain entity
- Complex mapping logic is needed

When entities serialize directly (e.g., via Jackson), no separate persistence model is needed.

### Database Migrations

- Every schema change requires a migration script
- Migrations are versioned and ordered (never modify an existing migration)
- Migrations must be backwards-compatible when possible (add columns as nullable, then backfill)
- Destructive migrations (drop column, drop table) require explicit review

## External Service Adapters

External integrations (email, payment gateways, third-party APIs) follow the same port/adapter pattern:

- Port defined in the domain center
- Adapter implementation in the application layer
- Handle success, failure, and timeout scenarios

## Dependency Rules

```
Application depends on: Entities, Interactors, Events
Nothing depends on: Application
```

The application layer is the outermost circle. It depends on everything inside it, but nothing depends on it. All components here are plugins — replaceable without modifying business logic.

## Testing

- **Controller tests**: Verify HTTP contract (status codes, request/response mapping, error handling)
- **Store integration tests**: Verify queries return correct results with real database, persistence mapping works, migrations apply cleanly
- **External adapter tests**: Verify success, failure, and timeout handling

Controller tests use interactors. Store tests use test containers or embedded databases. As a result these tests have a very easy setup (only (controller or store) and domain setup) but test security, serialization, error handling, persistence, transaction boundaries, etc. in conjunction with business logic.
