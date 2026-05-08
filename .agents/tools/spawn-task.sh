#!/usr/bin/env bash
set -euo pipefail

# spawn-task.sh - Initialize an agent team for a specific task
#
# Usage: ./spawn-task.sh --module <module> --goal <goal-file-or-description> --task-id <id>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$AGENTS_DIR")"

MODULE=""
GOAL=""
TASK_ID=""
EXPERIMENTS=2

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Initialize an agent team for a specific task.

Options:
    --module <name>       Module to work on
    --goal <description>  Goal description or path to prompt file
    --task-id <id>        Unique task identifier
    --experiments <n>     Number of experiment branches (default: 2)
    -h, --help            Show this help message

Example:
    $(basename "$0") --module app --goal "Add user authentication" --task-id AUTH-001
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --module) MODULE="$2"; shift 2 ;;
        --goal) GOAL="$2"; shift 2 ;;
        --task-id) TASK_ID="$2"; shift 2 ;;
        --experiments) EXPERIMENTS="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "$MODULE" || -z "$GOAL" || -z "$TASK_ID" ]]; then
    echo "Error: --module, --goal, and --task-id are required"
    usage
fi

echo "=== Spawning Agent Team ==="
echo "Module:      $MODULE"
echo "Task ID:     $TASK_ID"
echo "Goal:        $GOAL"
echo "Experiments: $EXPERIMENTS"
echo ""

TASK_DIR="$AGENTS_DIR/playgrounds/$TASK_ID"
PLAN_FILE="$AGENTS_DIR/plans/$TASK_ID.plan.md"

if [[ -d "$TASK_DIR" ]]; then
    echo "Warning: Task directory already exists: $TASK_DIR"
    read -p "Continue and overwrite? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    rm -rf "$TASK_DIR"
fi

mkdir -p "$TASK_DIR"

GOAL_CONTENT="$GOAL"
if [[ -f "$GOAL" ]]; then
    GOAL_CONTENT=$(cat "$GOAL")
elif [[ -f "$REPO_ROOT/.github/prompts/$GOAL" ]]; then
    GOAL_CONTENT=$(cat "$REPO_ROOT/.github/prompts/$GOAL")
fi

cat > "$PLAN_FILE" <<EOF
# Task: $TASK_ID

## Module
$MODULE

## Goal
$GOAL_CONTENT

## Status
- [ ] Task initialized
- [ ] Agents assigned
- [ ] Implementation in progress
- [ ] Validators passed
- [ ] Tests green
- [ ] Commit prepared

## Backend Tasks (@backend-agent)
- [ ] Analyze requirements
- [ ] Implement domain changes
- [ ] @backend-validator: architecture compliance check

## Frontend Tasks (@frontend-agent)
- [ ] Analyze requirements
- [ ] Implement UI changes
- [ ] @frontend-validator: a11y + i18n check

## Acceptance Tasks (@acceptance-agent)
- [ ] Update DSL if needed
- [ ] Update protocol drivers
- [ ] Verify tests pass

## Experiments
$(LETTERS=(a b c d e f g h); for i in $(seq 1 "$EXPERIMENTS"); do echo "- [ ] experiment-${LETTERS[$((i-1))]}: (describe approach)"; done)

## Results
<!-- Agent notes and evaluation results go here -->

## Final Checklist
- [ ] All validators green
- [ ] All acceptance tests green
- [ ] No regressions in module tests
- [ ] Commit message drafted

---
Created: $(date -Iseconds)
EOF

echo "Created plan: $PLAN_FILE"

CURRENT_BRANCH=$(git -C "$REPO_ROOT" branch --show-current)

LETTERS=(a b c d e f g h)
for i in $(seq 1 "$EXPERIMENTS"); do
    EXPERIMENT_NAME="experiment-${LETTERS[$((i-1))]}"
    EXPERIMENT_DIR="$TASK_DIR/$EXPERIMENT_NAME"
    BRANCH_NAME="agents/$TASK_ID/$EXPERIMENT_NAME"

    echo "Creating experiment: $EXPERIMENT_NAME"

    if ! git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        git -C "$REPO_ROOT" branch "$BRANCH_NAME" "$CURRENT_BRANCH"
    fi

    git -C "$REPO_ROOT" worktree add "$EXPERIMENT_DIR" "$BRANCH_NAME" 2>/dev/null || {
        echo "  Worktree already exists or failed, using existing"
    }
done

cat > "$TASK_DIR/results.md" <<EOF
# Experiment Results: $TASK_ID

## Evaluation Criteria
- [ ] Functionality complete
- [ ] Tests passing
- [ ] Code quality (validators)
- [ ] Performance acceptable
- [ ] No regressions

## Experiment A
**Approach:** (describe)

**Pros:**
-

**Cons:**
-

**Verdict:** (pending | winner | rejected)

## Experiment B
**Approach:** (describe)

**Pros:**
-

**Cons:**
-

**Verdict:** (pending | winner | rejected)

## Decision
Selected experiment: (a | b | merge)
Reason:

---
Evaluated: (timestamp)
EOF

echo "Created results template: $TASK_DIR/results.md"
echo ""
echo "=== Task Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit plan:        $PLAN_FILE"
echo "  2. Work in experiments:"
LETTERS=(a b c d e f g h)
for i in $(seq 1 "$EXPERIMENTS"); do
    EXPERIMENT_NAME="experiment-${LETTERS[$((i-1))]}"
    echo "     - $TASK_DIR/$EXPERIMENT_NAME"
done
echo "  3. Track progress:   .agents/tools/plan-tracker.sh $TASK_ID"
echo "  4. Prepare commit:   .agents/tools/commit-preparer.sh $TASK_ID --experiment a"
