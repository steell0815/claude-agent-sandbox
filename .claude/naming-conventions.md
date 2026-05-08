# Naming Conventions

Stack-agnostic naming patterns for all circles of the Clean Architecture. Specific casing (PascalCase, camelCase, snake_case, kebab-case) is determined by the stack overlay. The patterns below define the **semantic naming structure**.

## Entities (Domain Center)

| Type | Pattern | Example |
|------|---------|---------|
| Entity | `{Noun}` | `Order`, `User`, `Invoice` |
| Value Object (Identity) | `{Entity}Id` | `OrderId`, `UserId` |
| Value Object (Business) | `{Concept}` (noun describing the value) | `Money`, `EmailAddress`, `DateRange` |
| Value Object (Embedded) | `{Parent}{Concept}` | `OrderTotal`, `UserPreferences` |
| Child Entity | `{Noun}` (accessed through entity) | `OrderLine`, `InvoiceItem` |
| Store Port | `{Entity}Store` or `Store<{Entity}>` | `OrderStore`, `Store<Order>` |
| Domain Service | `{Verb}{Noun}Service` or `{Concept}Policy` | `CalculatePricingService`, `DiscountPolicy` |
| Cause Event | `{Verb}{Entity}` (imperative) | `SubmitActor`, `PlaceOrder`, `CancelInvoice` |
| Effect Event | `{Entity}{PastTenseVerb}` (past tense) | `ActorSubmitted`, `OrderPlaced`, `InvoiceCancelled` |
| Enum | `{Concept}` (singular noun) | `OrderStatus`, `PaymentMethod` |
| Builder (construct) | `{Entity}.builder()...build()` | `Order.builder().customerId(id).build()` |
| Builder (modify) | `{instance}.toBuilder()...build()` | `order.toBuilder().status(SHIPPED).build()` |

## Interactors / Use Cases

| Type | Pattern | Example |
|------|---------|---------|
| Use Case | `{Verb}{Noun}UseCase` | `PlaceOrderUseCase`, `RegisterUserUseCase` |
| Interactor (facade) | `{Entity}Interactor` | `OrderInteractor`, `UserInteractor` |
| Request Model | `{Verb}{Noun}Request` | `PlaceOrderRequest`, `UpdateUserRequest` |
| Response Model | `{Noun}Response` | `OrderResponse`, `UserResponse` |

## Application (Execution Environment)

| Type | Pattern | Example |
|------|---------|---------|
| Controller | `{Entity}Controller` | `OrderController`, `UserController` |
| API Prefix | `/api/{version}/{entity-plural}` | `/api/v1/orders` |
| Exception Handler | `{Scope}ExceptionHandler` | `GlobalExceptionHandler`, `OrderExceptionHandler` |
| Store Adapter | `{Entity}StoreAdapter` | `OrderStoreAdapter`, `UserStoreAdapter` |
| Technology Store | `{Entity}{Tech}Store` | `OrderJpaStore`, `UserPrismaStore` |
| Persistence Model (optional) | `{Entity}Record` | `OrderRecord`, `UserRecord` |
| Persistence Mapper (optional) | `{Entity}PersistenceMapper` | `OrderPersistenceMapper` |
| Migration | `{Version}_{description}` | `V001_create_orders_table` |
| External Adapter | `{Service}Adapter` | `EmailAdapter`, `PaymentGatewayAdapter` |

> **Note:** Persistence models and mappers are optional. Entities may serialize directly (e.g., via Jackson or similar). Use separate persistence models only when the database representation diverges significantly from the domain model.

## Frontend

| Type | Pattern | Example |
|------|---------|---------|
| Page / View | `{Feature}Page` or `{Feature}View` | `OrderListPage`, `OrderDetailView` |
| UI Component | `{Descriptive}Component` or `{Descriptive}` | `OrderTable`, `OrderStatusBadge` |
| State Store | `{Feature}Store` or `use{Feature}` | `OrderStore`, `useOrders` |
| API Service | `{Entity}ApiService` or `{entity}Api` | `OrderApiService`, `orderApi` |
| Domain Model | `{Concept}` (mirrors backend domain) | `Order`, `OrderStatus` |
| Mapper (frontend) | `{Entity}Mapper` | `OrderMapper` |

## Tests

| Type | Pattern | Example |
|------|---------|---------|
| Unit Test | `{Subject}Test` or `{Subject}.test` | `OrderTest`, `Order.test.ts` |
| Integration Test | `{Subject}IntegrationTest` | `OrderStoreIntegrationTest` |
| Acceptance Test | `{Feature}Test` | `PlaceOrderTest` |
| DSL | `{Feature}DSL` | `PlaceOrderDSL` |
| Domain Driver | `{Feature}DomainDriver` | `PlaceOrderDomainDriver` |
| Controller Driver | `{Feature}ControllerDriver` | `PlaceOrderControllerDriver` |
| Test Helper / Builder | `{Entity}Builder` or `{Entity}Mother` | `OrderBuilder`, `OrderMother` |
| In-Memory Test Store | `InMemory{Entity}Store` | `InMemoryOrderStore` |

## General Principles

1. **Names reflect the domain, not the technology** — `OrderStore`, not `OrderRepository` or `OrderDAO`. Store is technology-neutral; Repository implies Spring Data JPA.
2. **Pluralization follows natural language** — collection endpoints use plural (`/orders`), types use singular (`Order`)
3. **Abbreviations are banned** — `Store`, not `Sto`; `Interactor`, not `Int`; `Configuration`, not `Config`
4. **Boolean names are assertions** — `isActive`, `hasPermission`, `canEdit` — never `active`, `permission`, `edit`
5. **Effect event names are past tense. Cause event names are imperative.** — Effect: `OrderPlaced`, Cause: `PlaceOrder`
6. **Causes are input events (what is requested), Effects are output events (what happened)** — Causes designed outside-in, Effects designed inside-out
