# /analyze-repo - Analyze Repository for Blueprint Evolution

Analyze a git repository for notable practices, compare them against the current blueprint, and create one PR per suggestion for human review. Each suggestion is a hypothesis backed by evidence.

## Arguments

- `<repo-path>`: Path to the git repository to analyze
- `--drift` (optional): Drift mode — analyze a blueprint-derived repo to detect evolved practices that should flow back upstream
- `--categories <list>` (optional): Comma-separated category filter (adr, testing, cicd, architecture, workflow, stack). Default: all categories.

## Modes

- **Discover mode** (default): Analyze any git repository for practices worth adopting into the blueprint
- **Drift mode** (`--drift`): Analyze a blueprint-derived repo to detect deliberate divergences that represent evolved practices

## Workflow

### 1. Validate target repository

Confirm the target path is a git repository and detect its tech stack:

```bash
.agents/tools/analyze-repo.sh --target <repo-path> [--drift] [--categories <list>]
```

- Verify `.git/` exists at the target path
- Detect languages via file extensions (`*.java`, `*.ts`, `*.py`, `*.go`, etc.)
- Detect frameworks via config files (`pom.xml`, `package.json`, `build.gradle`, `requirements.txt`, etc.)
- If blueprint-derived structure detected (`.claude/` + `docs/adr/` matching blueprint pattern), suggest `--drift` mode

### 2. Index the blueprint baseline

Load the current blueprint state as the comparison baseline:

- Read all ADRs from `docs/adr/adr.md` index — extract titles and key decisions
- Read `.claude/guardrails.md` — extract all instant failures (IF-*) and golden rules (GR-*)
- Read `.claude/workflows.md` — extract workflow names and key steps
- Read `.claude/*-layer.md` files — extract architectural patterns per layer
- Read `stacks/` directory — catalog stack-specific configurations
- Read `.agents/config/agents.yaml` — understand current agent team structure

Store this as a structured summary for analyst agents to reference.

### 3. Dispatch parallel analyst agents

Launch specialist analysts in parallel (see `.agents/config/analysis-agents.yaml`):

| Analyst | Focus | Category filter |
|---------|-------|-----------------|
| `adr-analyst` | Architectural decisions | `adr` |
| `practice-analyst` | Guardrails, patterns, workflow | `architecture`, `workflow` |
| `test-analyst` | Testing patterns and config | `testing` |
| `pipeline-analyst` | CI/CD, security, deployment | `cicd` |

Each analyst receives:
- Target repo path (read-only access)
- Blueprint baseline summary
- Category-specific heuristics from `.agents/workflows/analysis-heuristics.md`
- Standardized finding schema to populate

Each analyst produces findings in the format defined in `.agents/workflows/analyze-repo.md`.

If `--categories` is specified, only dispatch analysts matching the requested categories.

### 4. Rank and filter findings

The coordinator scores each finding on four dimensions (0-10 each, minimum 20/40 to proceed):

| Dimension | Description |
|-----------|-------------|
| Novelty | Not already covered by existing ADRs/guardrails/docs |
| Generality | Applicable across stacks and domains, not project-specific |
| Evidence | Concrete code/config proof, not just documentation mentions |
| Alignment | Consistent with blueprint philosophy (DDD, Clean Architecture, BDD, Minimum CD) |

**Automatic exclusions:**
- Findings that contradict existing ADRs (flagged in report but not committed)
- Framework-version-only differences (no architectural insight)
- Purely stylistic preferences
- Low confidence findings
- Project-specific configurations

**Cap**: Maximum 15 PRs per analysis run.

### 5. Create PRs for accepted findings

For each surviving finding, the `blueprint-writer` agent:

1. Creates a branch: `analyze/{target-repo-name}/{finding-slug}`
2. Makes the appropriate blueprint change:
   - **New ADR**: Follow `/add-adr` pattern (next number, template, update index)
   - **New guardrail**: Follow `/add-guardrail` pattern (next IF/GR number, add to table)
   - **Architecture doc update**: Edit relevant `.claude/*-layer.md` file
   - **Testing doc update**: Edit BDD/testing guidance or add new test pattern
   - **CI/CD update**: Edit ADR-014 or CI workflow templates
   - **New workflow**: Add to `.claude/workflows.md`
   - **Stack-specific**: Edit under `stacks/{stack}/`
3. Commits with conventional message format
4. Creates PR via `gh pr create` with structured body (hypothesis, evidence, gap, category, confidence)

### 6. Produce summary report

Output a summary to stdout and save to `.agents/playgrounds/ANALYSIS-{id}/results.md`:

- Repository profile (languages, frameworks, mode)
- Table of created PRs with category and confidence
- Table of findings not submitted with reasons
- Any findings that contradicted existing ADRs (flagged for awareness)

## Example

```
/analyze-repo ~/projects/my-spring-app
/analyze-repo ~/projects/my-spring-app --drift
/analyze-repo ~/projects/my-spring-app --categories adr,testing
```

## Rules

- Never modify the target repository — it is read-only
- Every PR must contain a hypothesis explaining *why* the practice belongs in the blueprint
- Every PR must contain concrete evidence (quoted code/config) from the target repo
- Findings must be general enough to apply across stacks, not project-specific
- Maximum 15 PRs per analysis run — quality over quantity
- Contradictions with existing ADRs are reported but never committed
- Use technology-agnostic language in blueprint changes (consistent with ADR conventions)
- Branch names follow the pattern: `analyze/{repo-name}/{finding-slug}`
