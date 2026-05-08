# ADR-018: OpenTelemetry Business Function Instrumentation

## Status

Proposed

## Context

Features are built and deployed, but their actual usage and business value are assumed, not measured. The blueprint already acknowledges this gap in several places:

- **SECURITY.md** declares "observability as a security capability" (logs, metrics, traces, auth failure visibility)
- **ADR-004** (DORA metrics) lists "requires instrumentation" as a negative consequence — the tooling is missing
- **GR-14** says "no sensitive data in logs" but covers only logs, not spans, metrics, or trace attributes

Without business function telemetry, teams cannot answer fundamental questions: Is this feature used? Does it create value? Is it a maintenance burden? These questions are central to the SSDLC — an uninstrumented feature cannot be evaluated for continued investment or retirement.

At the same time, telemetry pipelines are typically less protected than production databases. Sensitive data that enters telemetry (PII, credentials, financial data) creates compliance violations and security exposure in systems that were never designed to protect it.

## Decision

Adopt OpenTelemetry (CNCF, vendor-neutral) as the standard for traces, metrics, and logs across all blueprint-derived projects. Instrumentation covers three telemetry categories:

### Telemetry Categories

| Category | Purpose | Examples |
|----------|---------|---------|
| Diagnostic | System health, latency, errors | HTTP request duration, DB query time, error counts |
| Business function | Feature adoption, value measurement | Use case invocation counts, success/failure rates, event throughput |
| SSDLC assessment | Feature lifecycle health | Usage trends over time, error-to-invocation ratios |

### Exclusion List (Hard Rule — IF-18)

The following data MUST NEVER appear in any telemetry signal (spans, metrics, logs, trace attributes):

- **PII**: Names, emails, phone numbers, addresses, government IDs
- **Credentials**: Passwords, tokens, API keys, session IDs
- **Financial data**: Account numbers, card numbers, individual transaction amounts
- **User identity correlation**: Any attribute allowing identification of a specific human

### Semantic Conventions

Telemetry naming follows OpenTelemetry-style dot-separated conventions, stack-agnostic:

**Spans:**
- Name pattern: `usecase.{verb}_{noun}` (e.g., `usecase.place_order`, `usecase.submit_actor`)
- Attributes: `usecase.name`, `usecase.outcome` (`success` | `failure` | `rejection`), `usecase.rejection_reason`

**Metrics:**
- `business.usecase.invocations` — counter, labels: `usecase.name`, `usecase.outcome`
- `business.usecase.duration` — histogram, labels: `usecase.name`
- `business.event.published` — counter, labels: `event.type`

**Namespaces:**
- `business.*` — business function and SSDLC assessment telemetry
- `system.*` — diagnostic telemetry (HTTP, DB, infrastructure)

### Architectural Placement

Instrumentation lives in the **application layer only**:

- Decorators/wrappers around interactors
- Controller middleware
- Store adapter decorators

The domain center remains pure per IF-01 and ADR-006. Entities, value objects, and interactor business logic contain zero instrumentation code.

### BDD Provability

Following the GR-15 pattern, acceptance tests prove:

- Telemetry signals are emitted when use cases execute (using an in-memory test exporter)
- Excluded data (PII, credentials, financial data) never appears in any telemetry signal
- Business metrics increment correctly for success, failure, and rejection outcomes

## Consequences

### Positive

- Features become measurable: teams can answer "is this feature used?" with data, not assumptions
- SSDLC decisions (continue, retire, invest) are backed by usage evidence
- Vendor-neutral standard (OpenTelemetry/CNCF) avoids lock-in to specific observability platforms
- Exclusion list as an instant failure (IF-18) prevents sensitive data from reaching less-protected telemetry pipelines
- Semantic conventions ensure consistency across all blueprint-derived projects
- Domain purity preserved: instrumentation is an application-layer concern

### Negative

- Requires instrumentation effort for every use case and event — adds work to feature delivery
- In-memory test exporters add test infrastructure per stack overlay
- Stack overlays must each provide their own OTel SDK integration patterns

### Neutral

- Diagnostic telemetry (HTTP, DB) is typically provided by framework auto-instrumentation — this ADR focuses on the business function layer that frameworks do not cover
- The ADR defines conventions and placement; stack overlays provide concrete implementation patterns
- GR-14 (secure coding) already prohibits sensitive data in logs; IF-18 extends this to all telemetry signals
