# ADR-015: Mutation Testing and Coverage Analysis

## Status

Accepted

## Context

Code coverage tells you what code your tests execute, but not how well those tests detect faults. A test suite can achieve 100% line coverage while asserting nothing meaningful — every line runs, but no mutation would be caught. Mutation testing addresses this gap by introducing small faults (mutants) into the code and checking whether tests detect them. A killed mutant means tests caught the fault; a surviving mutant means tests are weak at that point.

Running coverage and mutation testing separately gives an incomplete picture. Running them together in the same pipeline stage reveals the true effectiveness of the test suite: "95% coverage but 60% mutation score" means tests execute most code but catch few faults.

The question is where in the pipeline to run both, given the three-stage model from ADR-014.

### Options Considered

| Option | Trade-off |
|--------|-----------|
| Both in Commit Stage (incremental mutation) | Fast feedback; incremental mutation fits 5-minute budget |
| Coverage in Commit, Mutation in Acceptance | Splits a unified signal across stages; delays mutation feedback |
| New parallel "Test Quality" stage | Adds a 4th stage; over-engineered for the value delivered |
| Nightly scheduled job only | Not gating; catches regressions but doesn't prevent them |

## Decision

We add code coverage analysis and incremental mutation testing to the Commit Stage, after unit tests and before build.

### Code Coverage

Coverage instruments the existing unit test run with near-zero overhead:
- **Java**: JaCoCo Maven plugin with `check` goal for threshold enforcement
- **TypeScript**: Vitest v8 coverage provider (`--coverage`)

Coverage thresholds are enforced per Clean Architecture circle (see guardrails GR-09).

### Incremental Mutation Testing

Mutation testing runs only on files changed since the base branch, keeping execution within the 5-minute commit stage budget:
- **Java**: PiTest with `--since` / `withHistory` for incremental mode
- **TypeScript**: Stryker with `--since main` for incremental mode

Gate: ≥ 80% mutation score (killed mutants / total mutants) on changed files.

### Nightly Full-Codebase Mutation

A scheduled nightly job runs full-codebase mutation testing for trend tracking. This is informational — it does not gate deployments. It catches mutation score regressions in unchanged code over time.

### Metrics as Internal Indicators

Coverage percentages and mutation scores are diagnostic tools, not targets. Their purpose is to surface areas that may need attention — a surviving mutant or a coverage gap is a prompt for investigation, not an automatic verdict.

Design quality sometimes produces legitimate coverage gaps. Generated code, framework glue, and defensive branches that require infrastructure to trigger are examples where meeting a threshold would require distorting the design for the sake of a number. In these cases, the team documents the exclusion and its alternative verification rather than writing tests that add no real confidence.

The exclusion mechanism is defined in guardrails GR-09. Projects maintain a `docs/coverage-exclusions.md` file that records each exclusion with its rationale and the alternative verification strategy.

### Pipeline After Implementation

```
Push/PR → [Commit Stage]                → [Acceptance Stage] → [Deploy]
             ├─ Format, Lint, Typecheck       ├─ BDD (3 drivers)
             ├─ Unit Tests + Coverage         ├─ Security acceptance
             ├─ Mutation (changed files)      ├─ Performance acceptance
             ├─ SAST                          └─ SBOM
             └─ Build

Nightly → [Full Mutation Analysis] (informational, trend tracking)

Daily   → [DAST Stage] + [Dependabot]
```

## Consequences

### Positive

- Coverage and mutation results appear in the same stage, enabling unified quality signals
- Incremental mutation keeps the commit stage within the 5-minute target
- False confidence from high coverage with weak assertions is detected and prevented
- Nightly full-codebase runs track mutation score trends across the entire codebase
- Preserves the three-stage pipeline model from ADR-014

### Negative

- Incremental mutation may miss interactions between changed and unchanged code (mitigated by nightly full runs)
- Adds two new tool dependencies per stack (JaCoCo + PiTest for Java, v8 coverage + Stryker for TypeScript)
- Teams must learn to interpret mutation reports and fix surviving mutants

### Neutral

- Mutation thresholds (≥ 80% killed) apply only to changed files in the commit stage
- Adapter and controller circles are excluded from mutation testing (tested via integration and contract tests)
- The specific mutation testing tools are stack-level implementation details
