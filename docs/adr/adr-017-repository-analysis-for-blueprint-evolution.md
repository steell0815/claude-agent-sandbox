# ADR-017: Repository Analysis for Blueprint Evolution

## Status

Proposed

## Context

The blueprint is a living template that encodes architectural decisions, guardrails, testing patterns, and CI/CD practices. Today, improving the blueprint requires manual inspection of repositories and ad-hoc editing. This process does not scale: as more teams scaffold projects from the blueprint and evolve their practices, valuable insights remain trapped in individual repositories.

Two feedback loops are missing:

1. **Discovery**: When analyzing external repositories (open-source or internal), there is no systematic way to identify practices worth adopting into the blueprint. Good ideas are noticed anecdotally or not at all.
2. **Drift detection**: When a blueprint-derived project evolves a practice beyond what the blueprint specifies, that improvement never flows back upstream. The blueprint stagnates while its offspring advance.

Both loops require the same capability: structured comparison of a repository's practices against the blueprint baseline, with hypothesis-based suggestions that a human can review.

## Decision

Add a `/analyze-repo` skill backed by a team of specialist analyst agents. The analysis pipeline has four phases:

1. **Reconnaissance** — Parallel analyst agents (ADR, practice, testing, pipeline) scan the target repository using category-specific heuristics and compare findings against the current blueprint baseline.
2. **Ranking** — A coordinator scores each finding on four dimensions (novelty, generality, evidence, alignment) with a minimum threshold of 20/40 to proceed. Automatic exclusions filter noise (contradictions, version-only diffs, stylistic preferences, low confidence).
3. **PR creation** — For each accepted finding, a blueprint-writer agent creates a branch, makes the blueprint change following existing conventions (`/add-adr`, `/add-guardrail`), and opens a PR with a structured body containing the hypothesis, evidence, and confidence score.
4. **Reporting** — A summary report lists all created PRs and explains why excluded findings were filtered.

Two modes are supported:
- **Discover mode** (default): Analyze any git repository for transferable practices
- **Drift mode** (`--drift`): Analyze a blueprint-derived repository to detect practices that evolved beyond the blueprint baseline

Every suggestion is a hypothesis, not an assertion. The PR body explains *why* the practice belongs in the blueprint, backed by concrete evidence (quoted code/config). Human review determines whether each hypothesis is accepted.

A cap of 15 PRs per run prevents analysis noise from overwhelming reviewers.

## Consequences

### Positive

- Blueprint evolves from evidence gathered across real codebases, not only authorial opinion
- Every suggestion is auditable: PR body contains hypothesis, evidence, source file, and confidence score
- Human review remains the decision gate — agents suggest, humans decide
- Drift mode creates a feedback loop from derived projects back to the blueprint
- Parallel analyst architecture allows focused expertise per category (ADR, testing, CI/CD, practices)
- Maximum PR cap and scoring threshold prevent noise

### Negative

- Analysis quality depends on the analyst prompt quality and heuristic definitions — requires ongoing tuning
- False positives may still reach PR creation at the medium-confidence threshold
- Adds complexity to the blueprint's meta-tooling (new skill, agent config, workflow, heuristics, shell script)
- PR volume from frequent analysis runs could create review fatigue if not managed

### Neutral

- The analysis pipeline is read-only with respect to the target repository — no risk of modification
- Findings that contradict existing ADRs are flagged but never committed — contradictions surface for awareness without destabilizing the blueprint
- The agent team structure mirrors the existing `agents.yaml` pattern, maintaining consistency across the blueprint's agent configurations
