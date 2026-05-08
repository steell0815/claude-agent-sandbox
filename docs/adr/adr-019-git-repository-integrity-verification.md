# ADR-019: Git Repository Integrity Verification as Pipeline Gate

## Status

Proposed

## Context

Supply-chain attacks that corrupt git objects (e.g., injecting malicious tree entries via hasDotgit, zeroPaddedFilemode, or tampered SHAs) can bypass all application-level tests. The current pipeline (ADR-014) covers code quality (SAST, tests, coverage) and web security (DAST) but does not verify the integrity of the version control system itself. A corrupted repository can deliver compromised code that passes every other gate.

## Decision

Run `git fsck --full --no-dangling` as a required gate in both the pre-commit hook and the CI pipeline. Classify fsck findings into security-sensitive patterns that block the pipeline, versus warnings that are logged but non-blocking.

The check runs in three places for defense in depth:
1. **Pre-commit hook** — Catches integrity issues before they enter the local repository
2. **CI pipeline** — First step in the commit stage, before any build or test
3. **Pull request checks** — Validates contributor branches before merge

### Implementation

```bash
# Pre-commit hook / CI step
git fsck --full --no-dangling --no-progress 2>&1 | \
  grep -iE '(hasDot|hasDotgit|gitmodules|badFilemode|nulIn|badTree|zeroPaddedFilemode)' && exit 1
```

Security-sensitive patterns to block on:
- `hasDot`, `hasDotdot`, `hasDotgit` — Path traversal in tree entries
- `gitmodules` — Malicious submodule configurations
- `badFilemode`, `zeroPaddedFilemode` — Filesystem permission exploits
- `nulInCommit`, `nulInHeader` — Null byte injection
- `badTree`, `badParentSha1`, `badTreeSha1` — Object integrity violations

## Consequences

### Positive

- Detects repository corruption before it propagates to downstream systems
- Blocks known git object-level attack vectors (CVE-2018-11235, CVE-2024-32002)
- Low cost: `git fsck` runs in seconds on typical repositories
- Defense in depth: complements SAST/DAST which operate at different levels

### Negative

- Adds a few seconds to pre-commit and CI execution time
- May produce false positives on repositories with unusual but legitimate object structures
- Developers need to understand git internals to triage fsck warnings

### Neutral

- Does not replace SAST or dependency scanning — operates at a different layer
- Applies equally to all stacks and languages
