# Analyze Repository Workflow

## Purpose

This workflow describes how to analyze an external git repository for notable practices, compare them against the current blueprint, and create one PR per suggestion for human review. Each suggestion is a hypothesis backed by evidence from the target repo.

## Prerequisites

- Target repository path must be a valid git repository
- `gh` CLI must be authenticated for PR creation
- Blueprint repository must be on a clean branch (no uncommitted changes)

## Steps

### 1. Validate and Reconnaissance (analysis-coordinator)

- Confirm target path contains a `.git/` directory
- Detect languages by scanning file extensions:
  ```bash
  find <repo-path> -type f | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20
  ```
- Detect frameworks by checking for config files (`pom.xml`, `package.json`, `build.gradle`, `requirements.txt`, `go.mod`, `Cargo.toml`, etc.)
- If `--drift` mode: verify the target repo is blueprint-derived (presence of `.claude/` + `docs/adr/` with blueprint ADR structure)
- Create task directory: `.agents/playgrounds/ANALYSIS-{timestamp}/`

### 2. Index Blueprint Baseline (analysis-coordinator)

Build a structured summary of the current blueprint state:

**ADRs** — Read `docs/adr/adr.md` and extract:
- ADR numbers, titles, and status
- Key decisions from each ADR (one-line summary)

**Guardrails** — Read `.claude/guardrails.md` and extract:
- All instant failure rules (IF-*)
- All golden rules (GR-*)

**Architecture** — Read `.claude/*-layer.md` files and extract:
- Key patterns per layer (domain, application, infrastructure, interfaces)
- Dependency rules and constraints

**Testing** — Extract from CLAUDE.md and workflows:
- BDD 4-layer architecture description
- Test variant types (domain, controller, UI)
- Coverage and mutation testing thresholds

**CI/CD** — Extract from ADR-014 and workflow templates:
- Pipeline stage definitions
- Quality gate criteria

**Stacks** — List `stacks/` contents:
- Available stack configurations and their key properties

Store this baseline in `.agents/playgrounds/ANALYSIS-{timestamp}/baseline.md` for analyst reference.

### 3. Dispatch Analysts (analysis-coordinator → analysts in parallel)

Each analyst receives:
- Target repo path (read-only)
- Blueprint baseline summary
- Category-specific heuristics from `.agents/workflows/analysis-heuristics.md`
- The standardized finding schema (below)

**Finding schema** — each analyst populates one or more findings:

```markdown
## Finding: {title}

- **Category**: adr | guardrail-if | guardrail-gr | architecture | testing | cicd | workflow | stack
- **Source**: {target-repo-file}:{line-range}
- **Evidence**: {quoted code/config, max 20 lines}
- **Blueprint gap**: {what the blueprint currently says or lacks}
- **Hypothesis**: {why this practice belongs in the blueprint}
- **Confidence**: high | medium | low
- **Proposed change**:
  - Target file: {blueprint file to create/modify}
  - Change type: create | append | modify
  - Draft: {the proposed content}
```

Analysts write their findings to `.agents/playgrounds/ANALYSIS-{timestamp}/findings-{analyst-name}.md`.

### 4. Rank and Filter (analysis-coordinator)

Collect all findings from analyst outputs. Score each finding on four dimensions (0-10 per dimension):

| Dimension | Weight | Scoring Guide |
|-----------|--------|---------------|
| Novelty | 10 | 10 = completely new concept; 5 = extends existing coverage; 0 = already covered |
| Generality | 10 | 10 = applies to all stacks/domains; 5 = applies to most; 0 = project-specific |
| Evidence | 10 | 10 = concrete code/config with clear intent; 5 = partial evidence; 0 = just mentions |
| Alignment | 10 | 10 = directly supports DDD/Clean Arch/BDD/MinCD; 5 = compatible; 0 = conflicts |

**Minimum score to proceed**: 20/40

**Automatic exclusions** (flag in report, do not create PR):
- Findings that contradict existing ADRs
- Framework-version-only differences (e.g., "they use Spring Boot 3.2" without architectural insight)
- Purely stylistic preferences (formatting, naming conventions that differ but aren't better)
- Low confidence findings (analyst marked as `low`)
- Project-specific configurations (env vars, database names, API keys)

**Deduplication**:
- If multiple analysts found the same practice, merge into a single finding with combined evidence
- Keep the highest-scoring version, append evidence from others

**Cap**: Maximum 15 findings proceed to PR creation. If more than 15 pass the threshold, keep the top 15 by score.

Write ranked results to `.agents/playgrounds/ANALYSIS-{timestamp}/ranked-findings.md`.

### 5. Create PRs (blueprint-writer, sequential — one per finding)

For each accepted finding, in order of descending score:

**5a. Create branch**
```bash
git checkout -b analyze/{target-repo-name}/{finding-slug} main
```

**5b. Make the blueprint change**

Based on the finding category:

| Category | Action | Convention to Follow |
|----------|--------|---------------------|
| `adr` | Create new ADR file, update index | `/add-adr` skill pattern |
| `guardrail-if` | Add instant failure rule | `/add-guardrail` pattern (next IF-* number) |
| `guardrail-gr` | Add golden rule | `/add-guardrail` pattern (next GR-* number) |
| `architecture` | Edit relevant `.claude/*-layer.md` | Preserve existing structure, append section |
| `testing` | Edit BDD/testing docs or add pattern | Follow existing testing doc format |
| `cicd` | Edit ADR-014 or CI templates | Follow ADR amendment format |
| `workflow` | Add to `.claude/workflows.md` | Follow existing workflow numbering |
| `stack` | Edit under `stacks/{stack}/` | Follow stack-specific conventions |

**5c. Commit**
```
feat(blueprint): {short description}

Source: {target-repo-name} @ {file}:{lines}
Confidence: {high|medium}

{hypothesis paragraph}
```

**5d. Create PR**
```bash
gh pr create --title "{short description}" --body "$(cat <<'EOF'
## Hypothesis
{Why this practice belongs in the blueprint}

## Evidence
{Quoted code/config from the target repo with file paths}

## Blueprint Gap
{What the blueprint currently lacks}

## Category
{adr | guardrail | architecture | testing | cicd | workflow}

## Confidence
{high | medium} — Score: {n}/40

---
Discovered by `/analyze-repo {target-repo-path}`
EOF
)"
```

**5e. Return to main**
```bash
git checkout main
```

### 6. Summary Report (analysis-coordinator)

Output to stdout and save to `.agents/playgrounds/ANALYSIS-{timestamp}/results.md`:

```markdown
# Analysis: {target-repo-name}

## Profile
- Languages: {detected}
- Frameworks: {detected}
- Mode: discover | drift

## PRs Created
| # | PR | Category | Confidence | Title |
|---|----|-----------|-----------:|-------|
| 1 | #N | adr       | high       | ... |

## Findings Not Submitted
| Finding | Reason | Score |
|---------|--------|------:|
| ...     | Below threshold | 14 |
| ...     | Contradicts ADR-008 | N/A |

## ADR Contradictions Detected
| Finding | Contradicts | Details |
|---------|-------------|---------|
| ...     | ADR-008     | ... |
```

## Error Handling

- If the target repo is not a git repository, abort with a clear error message
- If `gh` is not authenticated, abort before PR creation phase and output findings as a local report
- If a branch already exists from a previous run, skip that finding and note it in the report
- If PR creation fails, log the error and continue with remaining findings
