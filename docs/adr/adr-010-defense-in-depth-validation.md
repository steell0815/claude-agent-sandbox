# ADR-010: Defense-in-Depth Validation via Value Objects

## Status

Accepted

## Context

Validation that exists only at the API boundary is fragile. Internal code paths (event handlers, batch jobs, migrations, direct service calls) can bypass API-level validation entirely, allowing invalid data to enter the domain. When validation is concentrated in a single layer, any entry point that skips that layer introduces a defect.

Value Objects provide a mechanism for encoding validation rules into the type system itself, making invalid state unrepresentable regardless of the entry point.

## Decision

We adopt defense-in-depth validation across three layers, with Value Objects as the innermost defense:

### Layer 1: Interface Validation (API Boundary)

The interfaces layer validates request **format**:

- Required fields are present
- Field types are correct (string, number, date)
- String lengths are within bounds
- Enum values are recognized

This validation produces user-friendly error messages and rejects obviously malformed requests early.

### Layer 2: Application Validation (Business Preconditions)

The application layer validates **preconditions** that require external state:

- Referenced entities exist (e.g., the customer ID in an order)
- The user has permission for the requested operation
- The target entity is in a valid state for the operation (e.g., order is not already shipped)

### Layer 3: Domain Validation (Invariants via Value Objects)

Value Objects validate **domain invariants** at construction time:

- A `Money` value object rejects negative amounts
- An `EmailAddress` value object rejects malformed email strings
- An `OrderId` value object rejects blank or null identifiers
- A `Quantity` value object rejects zero or negative values

**Construction of an invalid Value Object is impossible.** The constructor (or factory method) validates invariants and fails immediately if they are violated. There is no `validate()` method called separately — the object is valid by the fact that it exists.

### Pseudocode Example

```
class EmailAddress:
    constructor(value):
        if value is blank:
            throw "Email address cannot be blank"
        if not matches email pattern:
            throw "Invalid email format: {value}"
        this.value = value.trim().lowercase()

    // No setter. Immutable. Valid forever once constructed.
```

## Consequences

### Positive

- Invalid domain state is unrepresentable — the type system enforces invariants
- Every entry point (API, event handler, batch job) gets the same validation via Value Objects
- Validation rules are defined once in the Value Object, not duplicated across layers
- Enables "parse, don't validate" — raw inputs are parsed into validated types as early as possible

### Negative

- More types in the codebase (each validated concept becomes its own Value Object)
- Construction failures require meaningful error messages, adding development overhead
- Refactoring an existing codebase to adopt Value Objects can be a significant effort

### Neutral

- Defense-in-depth means some validation is intentionally redundant across layers — this is a feature, not a bug
- The specific mechanism for immutability (records, frozen objects, final fields) depends on the language
- Value Objects validate their own invariants only — cross-entity validation belongs in entity methods or domain services
