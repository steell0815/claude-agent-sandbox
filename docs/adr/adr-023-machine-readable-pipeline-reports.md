# ADR-023: Machine-Readable Pipeline Reports

## Status

Proposed

## Context

CI pipelines produce quality gate results (test outcomes, coverage, SAST findings, DAST results, validation checks) that are consumed in three ways: by the pipeline itself (pass/fail), by developers (investigation), and by downstream tooling (dashboards, trend analysis, audit). Most pipeline configurations only produce human-readable console output and a binary exit code. This makes trend analysis, audit trails, and cross-pipeline aggregation impossible without parsing logs.

## Decision

Every pipeline stage that produces quality gate results must emit a structured JSON report alongside its pass/fail exit code. Reports are uploaded as CI artifacts with retention appropriate to their purpose.

### Report Schema

```json
{
  "timestamp": "2026-03-27T14:00:00Z",
  "git_ref": "abc1234",
  "git_branch": "main",
  "trigger": "push",
  "stage": "commit",
  "checks": [
    {
      "id": "SAST-001",
      "name": "Semgrep application scan",
      "severity": "error",
      "passed": true,
      "message": "No findings"
    }
  ],
  "summary": {
    "total": 12,
    "passed": 11,
    "failed": 1,
    "warnings": 0
  }
}
```

### Required Fields

- **timestamp** — ISO 8601 UTC when the report was generated
- **git_ref** — Short commit hash for traceability
- **git_branch** — Branch name
- **trigger** — What initiated the pipeline (push, PR, schedule, manual)
- **stage** — Pipeline stage name (commit, acceptance, dast)
- **checks[]** — Array of individual check results with id, severity, passed, message
- **summary** — Aggregate counts

### Severity Model

- **error** — Blocks the pipeline. Must be fixed before merge.
- **warning** — Advisory. Logged and tracked but non-blocking.

### Artifact Retention

| Report Type | Retention |
|-------------|-----------|
| Build/test reports | 7 days |
| Security scan reports (SAST, DAST) | 90 days |
| Compliance/audit reports | 90 days |

### Output Channels

Pipeline scripts should emit results through multiple channels:
1. **JSON file** — Machine-readable, uploaded as artifact
2. **CI annotations** — Inline warnings/errors in PR view (e.g., `::error file=...`)
3. **Step summary** — Human-readable markdown in CI job summary

## Consequences

### Positive

- Enables trend dashboards across builds without log parsing
- Provides audit-ready evidence for compliance requirements
- Tiered retention distinguishes ephemeral build outputs from security evidence
- Structured check IDs enable automated triage and deduplication

### Negative

- Pipeline scripts must produce JSON output in addition to console logs
- Report schema needs versioning if it evolves
- Additional artifact storage costs for 90-day retention

### Neutral

- Does not prescribe specific dashboard tooling
- Compatible with any CI system that supports artifact uploads
