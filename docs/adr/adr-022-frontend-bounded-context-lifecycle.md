# ADR-022: Frontend Bounded Context Lifecycle

## Status

Proposed

## Context

The blueprint extensively covers backend Clean Architecture with layer documentation for domain, application, infrastructure, and interfaces. However, no guidance exists for frontend state lifecycle management.

Modern single-page applications face architectural challenges that mirror backend bounded contexts:

- **State scoping**: Global state stores become monolithic — every component accesses everything, creating implicit coupling
- **Resource leaks**: Real-time connections (SSE, WebSocket) opened on navigation are never closed, accumulating server-side resources
- **Lifecycle mismatch**: State initialized for one domain persists when the user navigates to another, causing stale data and memory bloat

Without guidance, frontend architectures default to global singletons — the frontend equivalent of a God Object. The Domain Shell pattern applies DDD's bounded context concept to frontend architecture.

## Decision

Each frontend domain MUST have a shell (layout/container) component that scopes state and real-time connections to its route subtree. The shell is the frontend equivalent of a bounded context boundary.

### Domain Shell Responsibilities

| Responsibility | Description |
|---------------|-------------|
| State scoping | Provides domain-specific state stores to its component subtree (not globally) |
| Connection lifecycle | Opens real-time connections (SSE/WebSocket) on mount, closes on unmount |
| Resource cleanup | Cancels pending requests, clears timers, unsubscribes from observables on teardown |
| Route binding | Mounted via router configuration at the domain's route prefix |

### Shell Structure (Framework-Agnostic)

```
domains/
  {domain-name}/
    {domain}-shell.{ext}           # Lifecycle boundary component
    {domain}-store.{ext}           # Domain-scoped state store
    components/                    # Domain-specific UI components
    pages/                         # Route-level page components
```

### Lifecycle Contract

```
Shell Mount (user navigates to domain):
  1. Initialize domain state store
  2. Open real-time connections (SSE/WebSocket)
  3. Load initial data

Shell Unmount (user navigates away):
  1. Close real-time connections
  2. Cancel pending requests
  3. Clear timers and subscriptions
  4. State store is garbage collected (not global)
```

### Framework Mapping

| Framework | Shell Implementation | State Scoping | Cleanup Hook |
|-----------|---------------------|---------------|--------------|
| Angular | Component with `providers: [Store]` | Hierarchical DI | `OnDestroy` |
| React | Layout component with `Context.Provider` | React Context | `useEffect` cleanup |
| Vue | Layout component with `provide()` | Provide/Inject | `onUnmounted` |
| Svelte | Layout `+layout.svelte` with `setContext()` | Context API | `onDestroy` |

### Rules

1. State stores are NOT global singletons — they are scoped to the domain shell that owns them
2. Real-time connections MUST be tied to the shell lifecycle — connect on mount, disconnect on unmount
3. Navigation away from a domain MUST trigger full cleanup (connections, timers, subscriptions)
4. Cross-domain communication uses events or shared services, not direct store access

## Consequences

### Positive

- State is naturally scoped — components can only access their domain's state
- Resource leaks are eliminated — cleanup is tied to the navigation lifecycle
- Domains are independently deployable — no shared global state to coordinate
- Mirrors backend bounded context thinking, creating a consistent DDD vocabulary across the stack

### Negative

- Cross-domain data sharing requires explicit event-based communication instead of direct store access
- Initial setup overhead per domain (shell component, scoped store, cleanup logic)
- Developers must understand the scoping model to avoid accidentally creating global state

### Neutral

- Shared UI components (design system, layout) remain global — only domain state is scoped
- The shell pattern does not prescribe a specific state management library
- Small applications with a single domain may use a single shell at the root level
