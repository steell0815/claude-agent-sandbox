# ADR-008: Adopt Clean Architecture

## Status

Accepted

## Context

As applications grow, business logic becomes entangled with infrastructure concerns (database access, HTTP handling, serialization). This entanglement makes the codebase brittle: changing a database schema requires modifying business rules, testing business logic requires spinning up infrastructure, and replacing a framework requires rewriting core functionality.

Clean Architecture (Robert C. Martin) organizes code as concentric circles with strict dependency rules — dependencies always point inward. The innermost circle contains the most valuable part of the system (business rules), and everything outside is a plugin that can be swapped without modifying the core.

## Decision

We adopt Clean Architecture with the following concentric circles, from inside out:

### Entities (Center)

Application-independent business rules. This is the core of the system.

- Entities (application-independent business rules)
- Value objects (identity and business)
- Domain services (logic spanning multiple entities)
- Store ports (interfaces for persistence — e.g., `Store<Order>`)
- Zero dependencies on any other circle, framework, or library

### Interactors / Use Cases

Application-specific business rules. This circle contains the actual business logic of the application.

- **Use Cases** — One class per use case (`PlaceOrderUseCase`, `CancelOrderUseCase`). Contains business logic, not just orchestration.
- **Interactors** — Facade grouping related use cases for a single entity (`OrderInteractor`). Provides a unified entry point.
- Depends only on Entities.

### Events (Separate Module)

Domain events using a Cause + Effect model. Events live in their own module, separate from entities.

- **Causes** — Imperative input events designed outside-in (`SubmitActor`, `PlaceOrder`). Represent what is being requested.
- **Effects** — Past-tense output events designed inside-out (`ActorSubmitted`, `OrderPlaced`). Represent what happened.
- Depends only on Entities (for shared types like IDs and value objects).

### Application (Outer Ring)

The execution environment. This is NOT an orchestration layer — it is where the system is assembled and run.

- Framework configuration (Spring config, Express setup)
- Dependency injection wiring (connecting store ports to store implementations)
- Controllers (HTTP endpoints — these are plugins)
- Store adapter implementations (connecting ports to databases)
- External service adapter implementations

All components in this circle are plugins. They can be replaced without affecting business rules.

### Dependency Rule

Dependencies point inward. Everything outside the domain center is a plugin.

```
Application → Events ──┐
Application → Interactors → Entities
             Events ──────→ Entities
```

- Inner circles never reference outer circles
- Entities depend on nothing
- Interactors and Events depend only on Entities
- Application depends on everything inside it but nothing depends on Application

### Key Constraints

- Domain code (Entities, Interactors) contains no framework imports, annotations, or decorators
- Controllers call interactors/use cases, not domain entities directly
- Store ports are defined in Entities; store implementations live in Application
- Events live in a separate module, never co-located with entities
- Each circle has appropriate test types (unit, integration, contract, acceptance)

## Consequences

### Positive

- Business logic is testable in complete isolation — no database, no framework, no network
- Technology choices (database, framework, messaging) can change without modifying domain code
- Clear separation of concerns — each circle has a well-defined responsibility
- Enforces the Ports and Adapters pattern (see ADR-006) at an architectural level
- Use case classes make the application's capabilities explicit and discoverable
- Cause + Effect event model makes the system's behavior bidirectionally traceable

### Negative

- More files than a simpler architecture (controller -> service -> repository)
- Requires discipline to maintain circle boundaries, especially under deadline pressure
- Separate events module adds a build/package dependency to manage

### Neutral

- The specific package/directory structure within each circle is determined by the stack overlay
- Framework-specific patterns (dependency injection, ORM configuration) live in the Application circle
- This architecture applies per bounded context — different contexts may evolve independently
