# ADR-009: Follow SOLID Principles

## Status

Accepted

## Context

Without explicit design principles, codebases tend toward high coupling, low cohesion, and rigid structures that resist change. Classes accumulate responsibilities, interfaces grow fat, and dependency direction becomes circular. The cost of every future change increases as the codebase grows.

The SOLID principles — Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, and Dependency Inversion — provide a proven framework for designing code that is easy to change, test, and extend.

## Decision

We follow the five SOLID principles as design guidelines across all layers:

### Single Responsibility Principle (SRP)

Every module, class, or function has one reason to change. In practice:

- An entity enforces business invariants — it does not handle persistence or serialization
- An interactor/use case contains application-specific business rules — it does not handle persistence or HTTP
- A controller handles HTTP — it does not validate business preconditions

### Open/Closed Principle (OCP)

Modules are open for extension and closed for modification. In practice:

- New behavior is added by creating new types (new event handlers, new value objects) rather than modifying existing ones
- Domain events enable extending system behavior without modifying the entity that publishes them
- Strategy patterns and polymorphism are preferred over conditional chains

### Liskov Substitution Principle (LSP)

Subtypes must be substitutable for their base types without altering correctness. In practice:

- Store adapter implementations honor the contract defined by the store port
- Event handler implementations process events without violating the handler contract
- Test doubles (mocks, stubs) behave consistently with the interface they implement

### Interface Segregation Principle (ISP)

Clients should not be forced to depend on interfaces they do not use. In practice:

- Store ports expose only the methods needed by their consumers
- Read and write operations may use separate interfaces when consumers need only one
- Use cases have focused interfaces rather than god-service facades

### Dependency Inversion Principle (DIP)

High-level modules (domain) do not depend on low-level modules (infrastructure). Both depend on abstractions. In practice:

- The domain defines store ports (interfaces); adapters provide implementations
- Interactors depend on port interfaces, not concrete stores
- This is enforced by Clean Architecture (see ADR-008)

## Consequences

### Positive

- Code is easier to change because modifications are localized to the module with the relevant responsibility
- Code is easier to test because dependencies are injected through interfaces
- Code is easier to extend because new behavior is added through new types, not modification of existing ones
- Aligns with the Ports and Adapters pattern and Clean Architecture already adopted

### Negative

- Strict adherence can lead to over-abstraction if applied dogmatically to simple cases
- More interfaces and smaller classes increase file count
- Requires judgment about when a principle applies and when YAGNI takes precedence

### Neutral

- SOLID principles are guidelines, not laws — pragmatic application is expected
- The principles reinforce each other: DIP enables OCP, SRP enables ISP
- Test-Driven Development naturally guides toward SOLID compliance because tightly coupled, multi-responsibility code is hard to test
