# API Conventions

> **Note:** In Clean Architecture, controllers live in the application (execution environment) layer, not a separate "Interfaces" layer. This document defines conventions for HTTP API design regardless of where controllers are physically located.

## Controllers

Controllers are thin plugins: receive request, call interactor/use case, return response.

```
function placeOrder(request):
    response = orderInteractor.placeOrder(request)
    return response
```

- No business logic — not even simple conditionals based on business rules
- All endpoints use a consistent API prefix (e.g., `/api/v1/{resource}`)
- List endpoints return bounded result sets (see GR-11 and GR-15)

### Instant Failures (Controller-Specific)

| Rule | Violation Example (pseudocode) |
|------|-------------------------------|
| No missing API prefix | Controller at `/orders` instead of `/api/v1/orders` |
| No list endpoints without bounded results | `GET /api/v1/orders` returning all orders without bounding |
| No unhandled business exceptions | Domain exception propagating as HTTP 500 |
| No internal error leakage | Stack trace or SQL error in HTTP response body |
| No business logic in controllers | `if order.total > 1000` inside a controller method |

## Request/Response Models

- Request models define the external contract (what clients send)
- Response models define the external contract (what clients receive)
- Request/response models map directly to/from domain types used by interactors
- Immutable after construction

## Error Handling

Exception handlers catch all exceptions and translate them to structured error responses:

- Business exceptions (domain rule violations) -> 4xx status codes with machine-readable error codes
- Security and resource access specific errors -> 401 - unauthorized, 403 - forbidden, 405 - http method not allowed
- Validation errors -> 400 with field-level error details
- Not-found exceptions -> 404
- Optimistic locking -> 409 - conflict
- Precondition failed -> 424 - failed dependency
- Unexpected errors -> 500 with a generic message (no stack traces, no SQL, no internal details)

Error response structure (MANDATORY for all error responses):
```
{
  "code": "ORDER_ALREADY_SHIPPED",           // machine-readable, stable error code
  "message": "Cannot cancel an order that has already been shipped",  // human-readable
  "details": [                               // optional field-level details
    { "field": "status", "message": "Order status is SHIPPED" }
  ],
  "timestamp": "2026-03-11T14:30:00Z"       // ISO-8601, server time
}
```

### Error Response Contract Rules

Every HTTP error response in the application MUST use this structured contract:

| Field | Required | Description |
|-------|----------|-------------|
| `code` | Yes | Machine-readable, stable error code (UPPER_SNAKE_CASE). Clients use this for programmatic handling. |
| `message` | Yes | Human-readable description. Safe for display — never contains stack traces or internal details. |
| `details` | No | Array of field-level or context-specific details. Used for validation errors (field name + message). |
| `timestamp` | No | ISO-8601 timestamp of when the error occurred. Aids debugging and correlation. |

A global exception handler MUST translate all exceptions into this structure:

| Exception Type | HTTP Status | Error Code Pattern |
|---------------|-------------|-------------------|
| Validation errors (format, type) | 400 | `VALIDATION_ERROR` |
| Business rule violations | 4xx (context-dependent) | Domain-specific (e.g., `ORDER_ALREADY_SHIPPED`) |
| Authentication failures | 401 | `UNAUTHORIZED` |
| Authorization failures | 403 | `FORBIDDEN` |
| Resource not found | 404 | `NOT_FOUND` or domain-specific |
| Optimistic locking conflicts | 409 | `CONFLICT` |
| Unexpected errors | 500 | `INTERNAL_ERROR` (generic, no internals leaked) |

## Bounded Results

List endpoint behavior (pagination, bounded results) is specified by acceptance tests. See guardrails GR-11 and GR-15.

- List endpoints return bounded result sets with sensible defaults
- The specific bounding mechanism is proven by acceptance tests running across all drivers

## API Versioning

- Use a versioning strategy consistently across all endpoints
- Version in the URL path (`/api/v1/`) or in headers — pick one and apply uniformly
- Breaking changes require a new version; additive changes do not

## Testing

Controller tests verify the HTTP contract:

- Correct HTTP status codes for success, validation errors, business errors, and not-found
- Request deserialization and response serialization
- Bounded result set handling
- Error response structure (correct codes, no leaked internals)
- Authentication and authorization enforcement

Controller tests use a the interactor — they include business logic but not persistence or any other port.
