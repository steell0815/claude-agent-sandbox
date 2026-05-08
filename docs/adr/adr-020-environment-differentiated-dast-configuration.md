# ADR-020: Environment-Differentiated DAST Rule Configuration

## Status

Proposed

## Context

ADR-014 establishes OWASP ZAP baseline scanning as a DAST stage gate with the criterion "no high-severity findings." In practice, a single rule configuration is insufficient because CI and production environments have fundamentally different security contexts:

- **CI scans** run over HTTP against a locally-built container — HSTS findings are false positives
- **Production scans** run over TLS against the live deployment — HSTS must be enforced
- Some findings are acceptable in development (e.g., CSP unsafe-inline for hot-reload) but must fail in production
- External OAuth/OIDC providers should be excluded from the spider scope to prevent scanning third-party services

Without environment-specific rule classification, teams either suppress too many findings (missing real issues) or fail on irrelevant findings (eroding trust in the pipeline).

## Decision

Maintain version-controlled DAST rule configuration files that explicitly classify each ZAP finding as FAIL, WARN, or IGNORE with documented rationale. Provide separate configurations per environment.

### Configuration Files

- **`dast/zap-rules.conf`** — CI environment (HTTP, no TLS, local containers)
- **`dast/zap-rules-production.conf`** — Production environment (TLS, real auth, public-facing)

### Classification Framework

| Classification | Meaning | Pipeline Effect |
|---------------|---------|-----------------|
| FAIL | Mandatory control — must be present | Blocks pipeline |
| WARN | Known deviation with documented rationale | Logged, does not block |
| IGNORE | Not applicable in this environment | Suppressed from output |

### Rule Configuration Template

```
# ZAP Baseline Rule Configuration
# Format: <rule-id>  <IGNORE|WARN|FAIL>  (<rationale>)

# --- Security Headers (FAIL in all environments) ---
10038   FAIL    (CSP header must be present)
10021   FAIL    (X-Content-Type-Options must be nosniff)
10020   FAIL    (X-Frame-Options must be DENY or SAMEORIGIN)
10036   FAIL    (Server version header must not leak)

# --- TLS-dependent (environment-specific) ---
10035   IGNORE  (HSTS: not applicable over HTTP in CI)
# In production config, this becomes:
# 10035   FAIL    (HSTS: required in production with TLS)
```

### Separate Workflows per Environment

- **CI DAST**: Triggers on push to main, daily schedule, and changes to `dast/` files. Scans the locally-built application.
- **Production DAST**: Triggers on a weekly schedule and manual dispatch. Scans the live deployment URL. Uses a spider exclusion hook to prevent scanning external OAuth providers.

### Artifact Retention

Security scan reports (HTML, JSON, Markdown) are uploaded as CI artifacts with **90-day retention** to support audit and incident investigation timelines, distinguishing them from ephemeral build outputs with shorter retention.

## Consequences

### Positive

- Eliminates false positives that erode pipeline trust
- Makes DAST rule decisions explicit, reviewable, and auditable
- Enables stricter production scanning without breaking CI
- 90-day retention provides audit trail for compliance

### Negative

- Two configuration files to maintain and keep synchronized
- Rule IDs are ZAP-specific — teams using other DAST tools need equivalent mappings
- Production DAST requires a reachable production URL

### Neutral

- Does not change which DAST tool is used — only how it is configured
- Complements ADR-014's three-stage pipeline by operationalizing the DAST stage
