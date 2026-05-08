# {Feature / Bounded Context Name}

> Last updated: YYYY-MM-DD

## Key Type Contracts

### {EntityName}

| Field | Type | Constraints |
|-------|------|-------------|
| id | {EntityName}Id | Required, immutable |
| ... | ... | ... |

### {ValueObjectName}

| Field | Type | Constraints |
|-------|------|-------------|
| ... | ... | ... |

### {CauseEventName}

| Field | Type | Description |
|-------|------|-------------|
| ... | ... | ... |

### {EffectEventName}

| Field | Type | Description |
|-------|------|-------------|
| ... | ... | ... |

## File Manifest

### Backend

| Circle | File | Purpose |
|--------|------|---------|
| Entity | `path/to/Entity.ext` | Entity |
| Entity | `path/to/ValueObject.ext` | Value object |
| Entity | `path/to/Store.ext` | Store port |
| Interactor | `path/to/UseCase.ext` | Use case |
| Interactor | `path/to/Interactor.ext` | Interactor facade |
| Events | `path/to/Cause.ext` | Cause event |
| Events | `path/to/Effect.ext` | Effect event |
| App | `path/to/StoreAdapter.ext` | Store implementation |
| App | `path/to/Migration.ext` | DB migration |
| App | `path/to/Controller.ext` | HTTP endpoints |
| App | `path/to/Request.ext` | Request model |
| App | `path/to/Response.ext` | Response model |

### Frontend

| Type | File | Purpose |
|------|------|---------|
| Page | `path/to/Page.ext` | Main view |
| Component | `path/to/Component.ext` | UI component |
| Store | `path/to/Store.ext` | State management |
| API Service | `path/to/ApiService.ext` | Backend communication |
| Model | `path/to/Model.ext` | Frontend domain model |

## Architecture Notes

- {Key design decisions for this feature}
- {Relationships to other bounded contexts}
- {State machine description if applicable}

## API Endpoints

| Method | Path | Request | Response | Description |
|--------|------|---------|----------|-------------|
| POST | `/api/v1/{resource}` | `CreateRequest` | `Response` | Create new |
| GET | `/api/v1/{resource}/{id}` | - | `Response` | Get by ID |
| GET | `/api/v1/{resource}` | `?page=&size=` | `PagedResponse` | List (paginated) |

## Gotchas / Notes

- {Non-obvious behaviors}
- {Known edge cases}
- {Workarounds and their reasons}
