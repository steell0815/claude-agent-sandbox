# ADR-021: Contract-First API Design

## Status

Proposed

## Context

The blueprint prescribes Clean Architecture (ADR-008), API-first development (GR-08), and explicit request/response mapping (GR-06). However, it does not specify HOW API contracts are defined or enforced. In practice, this means API shapes emerge from implementation rather than being designed upfront.

Without a formal contract specification:

- Backend and frontend cannot develop independently — one must wait for the other
- API documentation drifts from implementation over time
- Breaking changes are detected at integration time, not design time
- Consumer-driven contract testing has no baseline to test against

API specification languages (OpenAPI for REST, AsyncAPI for event-driven) provide machine-readable contracts that serve as the single source of truth for API shape, enabling code generation, documentation, and compatibility checking.

## Decision

Public and internal REST APIs MUST be defined in an API specification format before implementation begins. Event schemas for real-time communication SHOULD be defined in a specification format.

### Specification Standards

| Communication | Specification | Format |
|--------------|---------------|--------|
| REST APIs | OpenAPI 3.x | YAML or JSON |
| Event-driven / messaging | AsyncAPI 2.x+ | YAML or JSON |
| GraphQL | SDL schema | `.graphql` files |

### Contract-First Workflow

1. **Design**: Define the API contract (OpenAPI/AsyncAPI spec) as part of the feature design
2. **Review**: API contract changes go through review — they affect all consumers
3. **Generate** (optional): Generate server interfaces and client SDKs from the spec where tooling supports it
4. **Implement**: Backend implements the generated interface or matches the spec manually
5. **Verify**: Controller tests verify that responses match the contract

### Spec Location

API specifications live alongside the code they describe:

```
{module}/
  src/main/resources/openapi/     # REST API specs
  src/main/resources/asyncapi/    # Event specs
```

Or in a dedicated contracts directory for cross-module APIs:

```
specs/
  {domain}-api.yaml              # REST API spec
  {domain}-events.yaml           # Event schema spec
```

### Code Generation

Code generation from specs is RECOMMENDED but not required. When used:

- Generated code lives in a build output directory (not committed to source control)
- Generated interfaces define the contract; implementations provide the behavior
- Generated client SDKs enable type-safe consumer integration

### Relationship to Existing Principles

| Principle | How Contract-First Supports It |
|-----------|-------------------------------|
| GR-06: Request/Response Mapping | Spec defines the exact shape of request/response models |
| GR-08: API-First Development | Spec IS the API-first artifact |
| ADR-013: Domain Events | AsyncAPI defines event schemas with the same rigor as REST contracts |
| GR-15: BDD-Provable | Contract tests verify spec compliance as part of acceptance testing |

## Consequences

### Positive

- Backend and frontend develop independently against a shared contract
- API documentation is always in sync (generated from the spec)
- Breaking changes are detected at design time, not integration time
- Code generation reduces boilerplate and eliminates manual mapping errors
- Consumer-driven contract testing has a formal baseline

### Negative

- Upfront design effort for each API endpoint before implementation
- Spec maintenance overhead when APIs evolve frequently during prototyping
- Code generation tooling varies in quality across languages and frameworks

### Neutral

- This ADR does not mandate a specific code generation tool — stack overlays provide recommendations
- For rapid prototyping (ADR-007), a lightweight spec can be refined iteratively
- Internal APIs between tightly-coupled modules may use a simpler contract approach
