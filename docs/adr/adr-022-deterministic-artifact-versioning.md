# ADR-022: Deterministic Artifact Versioning with Commit Provenance

## Status

Proposed

## Context

Deployed artifacts (container images, packages, documents, API responses) need to be traceable back to their exact source commit. Manual version management is error-prone and creates gaps in the audit trail. Without commit provenance embedded in the version string, answering "which commit produced this artifact?" requires cross-referencing CI logs, tags, and deployment records.

## Decision

Every versioned artifact carries a deterministic version string that combines a human-managed semantic version with build metadata:

```
{MAJOR.MINOR}-{YYYYMMDDTHHMMSSz}-{7-char-commit-hash}
```

**Examples:**
- Document: `**Version:** 1.0-20260311T095208Z-99958ff`
- Docker tag: `myapp:2.3-20260327T140000Z-abc1234`
- Package: `mylib@1.5.0-20260327T140000Z-abc1234`

### Stamping Rules

1. The human-managed part (`MAJOR.MINOR` or semver) is maintained manually in source files
2. The build metadata (`-{timestamp}-{hash}`) is appended automatically at commit time via a pre-commit hook or CI step
3. The stamp script only modifies staged files — it does not touch unstaged work
4. Modified files are re-staged automatically after stamping
5. A `--dry-run` mode must exist for CI validation without file modification

### Implementation Pattern

```bash
# Pre-commit hook phase
python stamp-versions.py --staged-only
git add -u  # Re-stage stamped files
```

The stamp script:
- Finds version fields matching a known pattern (e.g., `**Version:** X.Y`)
- Appends UTC timestamp and short commit hash
- Preserves the human-managed base version
- Is idempotent — re-stamping replaces the previous metadata suffix

## Consequences

### Positive

- Any artifact can be traced to its exact source commit without external lookups
- Stamping is automatic — developers manage only the semantic version
- Build metadata is deterministic and reproducible
- Works across all artifact types (documents, containers, packages)

### Negative

- Pre-commit hooks must be installed for local stamping to work
- Version strings are longer and less human-friendly
- Requires convention on where version fields appear in each artifact type

### Neutral

- Does not replace semantic versioning — extends it with provenance metadata
- Compatible with git tags, which can still mark release points
