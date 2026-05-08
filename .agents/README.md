# Multi-Agent Development Infrastructure

This directory contains the infrastructure for coordinating multiple AI agents working on the claude-agent-sandbox repository.

## Architecture

```
.agents/
├── config/                    # Agent team configurations
│   ├── agents.yaml            # Development agents (backend, frontend, acceptance)
│   └── analysis-agents.yaml   # Analysis agents (adr, practice, test, pipeline)
├── plans/                     # Active task plans
├── playgrounds/               # Experiment worktrees and analysis results (.gitignored)
├── workflows/                 # Workflow templates
│   ├── analyze-repo.md        # Repository analysis workflow and finding schema
│   └── analysis-heuristics.md # Detection patterns for analyst agents
└── tools/                     # Shell scripts for agent orchestration
    ├── analyze-repo.sh        # Initialize repository analysis
    ├── spawn-task.sh           # Spawn task with experiment branches
    ├── plan-tracker.sh         # Track plan progress
    ├── worktree-manager.sh     # Manage experiment worktrees
    └── commit-preparer.sh      # Prepare commit from experiment
```

## Quick Start

### 1. Spawn a new task

```bash
.agents/tools/spawn-task.sh \
  --module <module-name> \
  --goal "Make acceptance test X pass" \
  --task-id TASK-001
```

This creates:
- A plan file at `.agents/plans/TASK-001.plan.md`
- Experiment worktrees at `.agents/playgrounds/TASK-001/experiment-{a,b}/`
- A results template at `.agents/playgrounds/TASK-001/results.md`

### 2. Track progress

```bash
# Show overall progress
.agents/tools/plan-tracker.sh TASK-001

# Mark items as done
.agents/tools/plan-tracker.sh TASK-001 --check "Implement domain"

# Show pending items
.agents/tools/plan-tracker.sh TASK-001 --pending
```

### 3. Work in experiments

Each experiment is a separate git worktree with its own branch:
- `experiment-a/` → branch `agents/TASK-001/experiment-a`
- `experiment-b/` → branch `agents/TASK-001/experiment-b`

```bash
# Check status of all experiments
.agents/tools/worktree-manager.sh status TASK-001

# Sync experiments with base branch
.agents/tools/worktree-manager.sh sync TASK-001

# Add another experiment
.agents/tools/worktree-manager.sh create TASK-001 experiment-c
```

### 4. Prepare commit from winning experiment

```bash
# Create patch file
.agents/tools/commit-preparer.sh TASK-001 --experiment experiment-a

# Or prepare squashed commit message
.agents/tools/commit-preparer.sh TASK-001 --experiment experiment-a --squash
```

### 5. Cleanup

```bash
# Remove all worktrees and branches for a task
.agents/tools/worktree-manager.sh cleanup TASK-001
```

## Agent Team Structure

### Working Agents
- **backend-agent**: Backend logic, domain, controllers
- **frontend-agent**: UI components, i18n
- **acceptance-agent**: BDD tests, DSL, protocol drivers

### Validator Agents (Wingmen)
- **backend-validator**: Clean Architecture compliance, security
- **frontend-validator**: a11y, i18n, linting
- **dsl-validator**: BDD patterns, no flaky tests

### Coordinator
- **module-coordinator**: Decomposes goals, syncs agents, tracks progress

### Analysis Agents (Repository Analysis)

Used by the `/analyze-repo` skill to analyze external repositories for blueprint-worthy practices. See `config/analysis-agents.yaml` for full configuration.

- **analysis-coordinator**: Orchestrates the full analysis pipeline (validate, baseline, dispatch, rank, PR, report)
- **adr-analyst**: Discovers architectural decisions in the target repo
- **practice-analyst**: Discovers guardrails, architectural patterns, and workflow practices
- **test-analyst**: Discovers testing patterns and quality measurement approaches
- **pipeline-analyst**: Discovers CI/CD, security, and deployment practices
- **blueprint-writer**: Creates blueprint change PRs for accepted findings

## Plan File Format

Plans use markdown with checkboxes that agents can update:

```markdown
## Backend Tasks (@backend-agent)
- [ ] Implement domain changes
- [x] Update controller
- [ ] @backend-validator: compliance check
```

The `@agent-name` annotations help track which agent owns which task.

## Integration with Repository Guidelines

Agents follow:
- `CLAUDE.md` — Build commands, architecture overview
- `.github/copilot-instructions.md` — Coding standards, TDD, BDD
- `docs/glossary.md` — Ubiquitous language

## Repository Analysis

The `/analyze-repo` skill uses analysis agents to examine external repositories for practices worth adopting into the blueprint. Invoke it via:

```
/analyze-repo ~/projects/my-spring-app
/analyze-repo ~/projects/my-spring-app --drift
/analyze-repo ~/projects/my-spring-app --categories adr,testing
```

Analysis results are stored in `playgrounds/ANALYSIS-{id}/`. See `workflows/analyze-repo.md` for the full workflow specification and `workflows/analysis-heuristics.md` for detection patterns.
