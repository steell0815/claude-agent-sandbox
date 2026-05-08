# ADR-021: Declarative Security Response Headers at Infrastructure Layer

## Status

Proposed

## Context

Security response headers (CSP, HSTS, X-Frame-Options, CORP, COEP, COOP, Permissions-Policy) are a critical defense layer against XSS, clickjacking, MIME sniffing, and Spectre-class attacks. When implemented per-application or per-framework, they are inconsistently applied, duplicated across services, and drift between environments. The blueprint's existing guardrails focus on code-level security (IF-02 injection, IF-05 error leakage, GR-14 secure coding) but have no guidance on HTTP response header enforcement.

## Decision

Declare security response headers once at the infrastructure layer (reverse proxy or API gateway configuration) rather than implementing them in application code. This creates a single enforcement point that is version-controlled, auditable, and independent of application framework.

### Required Headers

Every web-facing application must return these headers on all responses:

| Header | Value | Purpose |
|--------|-------|---------|
| Content-Security-Policy | `default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self' data:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'` | XSS mitigation, clickjacking prevention |
| Strict-Transport-Security | `max-age=31536000; includeSubDomains` | Force TLS (production only) |
| X-Content-Type-Options | `nosniff` | MIME sniffing prevention |
| X-Frame-Options | `DENY` | Clickjacking prevention (legacy browsers) |
| Permissions-Policy | `camera=(), microphone=(), geolocation=(), payment=()` | Feature restriction |
| Cross-Origin-Embedder-Policy | `require-corp` | Spectre isolation |
| Cross-Origin-Opener-Policy | `same-origin` | Spectre isolation |
| Cross-Origin-Resource-Policy | `same-origin` | Spectre isolation |

### Enforcement Points

1. **Reverse proxy config** (HAProxy, Nginx, Traefik) — Sets headers on all responses; single canonical source
2. **DAST test server** — Mirrors production headers so CI DAST scans verify header presence (closed-loop verification)
3. **DAST rule configuration** — FAILs the pipeline if any required header is missing (see ADR-020)

### Additional Hardening

- Strip server version strings from responses (`Server: webserver` or remove entirely)
- Enforce `SameSite=Lax` on all cookies via response rewriting
- Redirect HTTP to HTTPS with 301 (production)

## Consequences

### Positive

- Single source of truth for security headers, independent of application framework
- DAST automatically verifies header presence — closed-loop enforcement
- Changes to security policy are infrastructure changes, reviewable as code
- Applies to all stacks equally

### Negative

- CSP `unsafe-inline` may be needed for some frameworks — requires documented WARN exceptions
- Developers must understand header semantics to tune CSP for their application
- Reverse proxy adds a deployment dependency

### Neutral

- Does not replace application-level security (input validation, parameterized queries)
- HSTS is production-only; CI environments operate over HTTP
