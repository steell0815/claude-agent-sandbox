#!/usr/bin/env bash
set -euo pipefail

# worktree-manager.sh - Manage git worktrees for parallel experiments

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$AGENTS_DIR")"

ACTION="${1:-}"
TASK_ID="${2:-}"
EXPERIMENT="${3:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") <action> [arguments]

Actions:
    list                           List all agent worktrees
    create <task-id> <name>        Create a new experiment worktree
    remove <task-id> <name>        Remove an experiment worktree
    sync <task-id>                 Rebase all experiments on current base branch
    cleanup <task-id>              Remove all worktrees for a task
    status <task-id>               Show status of all experiments

Examples:
    $(basename "$0") list
    $(basename "$0") create TASK-001 experiment-c
    $(basename "$0") sync TASK-001
    $(basename "$0") cleanup TASK-001
EOF
    exit 1
}

list_worktrees() {
    echo "=== Agent Worktrees ==="
    git -C "$REPO_ROOT" worktree list | grep -E "agents/|playgrounds/" || echo "No agent worktrees found"
}

create_worktree() {
    [[ -z "$TASK_ID" || -z "$EXPERIMENT" ]] && usage

    TASK_DIR="$AGENTS_DIR/playgrounds/$TASK_ID"
    EXPERIMENT_DIR="$TASK_DIR/$EXPERIMENT"
    BRANCH_NAME="agents/$TASK_ID/$EXPERIMENT"
    CURRENT_BRANCH=$(git -C "$REPO_ROOT" branch --show-current)

    mkdir -p "$TASK_DIR"

    echo "Creating worktree: $EXPERIMENT_DIR"
    echo "Branch: $BRANCH_NAME (from $CURRENT_BRANCH)"

    if ! git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        git -C "$REPO_ROOT" branch "$BRANCH_NAME" "$CURRENT_BRANCH"
    fi

    git -C "$REPO_ROOT" worktree add "$EXPERIMENT_DIR" "$BRANCH_NAME"
    echo "Done. Work in: $EXPERIMENT_DIR"
}

remove_worktree() {
    [[ -z "$TASK_ID" || -z "$EXPERIMENT" ]] && usage

    EXPERIMENT_DIR="$AGENTS_DIR/playgrounds/$TASK_ID/$EXPERIMENT"
    BRANCH_NAME="agents/$TASK_ID/$EXPERIMENT"

    if [[ -d "$EXPERIMENT_DIR" ]]; then
        echo "Removing worktree: $EXPERIMENT_DIR"
        git -C "$REPO_ROOT" worktree remove "$EXPERIMENT_DIR" --force || true
    fi

    read -p "Also delete branch $BRANCH_NAME? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git -C "$REPO_ROOT" branch -D "$BRANCH_NAME" 2>/dev/null || true
    fi
}

sync_worktrees() {
    [[ -z "$TASK_ID" ]] && usage

    TASK_DIR="$AGENTS_DIR/playgrounds/$TASK_ID"
    BASE_BRANCH=$(git -C "$REPO_ROOT" branch --show-current)

    echo "Syncing experiments for $TASK_ID with $BASE_BRANCH"

    for EXPERIMENT_DIR in "$TASK_DIR"/experiment-*; do
        [[ -d "$EXPERIMENT_DIR" ]] || continue
        EXPERIMENT=$(basename "$EXPERIMENT_DIR")
        echo ""
        echo "=== Syncing $EXPERIMENT ==="

        cd "$EXPERIMENT_DIR"
        git fetch origin

        if git rebase "$BASE_BRANCH"; then
            echo "  Rebased successfully"
        else
            echo "  CONFLICT: Manual resolution needed in $EXPERIMENT_DIR"
            git rebase --abort
        fi
    done
}

cleanup_task() {
    [[ -z "$TASK_ID" ]] && usage

    TASK_DIR="$AGENTS_DIR/playgrounds/$TASK_ID"

    echo "Cleaning up task: $TASK_ID"

    for EXPERIMENT_DIR in "$TASK_DIR"/experiment-*; do
        [[ -d "$EXPERIMENT_DIR" ]] || continue
        EXPERIMENT=$(basename "$EXPERIMENT_DIR")
        BRANCH_NAME="agents/$TASK_ID/$EXPERIMENT"

        echo "Removing: $EXPERIMENT"
        git -C "$REPO_ROOT" worktree remove "$EXPERIMENT_DIR" --force 2>/dev/null || true
        git -C "$REPO_ROOT" branch -D "$BRANCH_NAME" 2>/dev/null || true
    done

    rm -rf "$TASK_DIR"
    echo "Cleanup complete"
}

show_status() {
    [[ -z "$TASK_ID" ]] && usage

    TASK_DIR="$AGENTS_DIR/playgrounds/$TASK_ID"

    echo "=== Status: $TASK_ID ==="

    for EXPERIMENT_DIR in "$TASK_DIR"/experiment-*; do
        [[ -d "$EXPERIMENT_DIR" ]] || continue
        EXPERIMENT=$(basename "$EXPERIMENT_DIR")

        echo ""
        echo "--- $EXPERIMENT ---"
        cd "$EXPERIMENT_DIR"

        echo "Branch: $(git branch --show-current)"
        echo "Commits ahead: $(git rev-list --count HEAD "^origin/$(git -C "$REPO_ROOT" branch --show-current)" 2>/dev/null || echo 'N/A')"

        CHANGES=$(git status --porcelain | wc -l | tr -d ' ')
        echo "Uncommitted changes: $CHANGES"

        if [[ "$CHANGES" -gt 0 ]]; then
            git status --short
        fi
    done
}

case "$ACTION" in
    list) list_worktrees ;;
    create) create_worktree ;;
    remove) remove_worktree ;;
    sync) sync_worktrees ;;
    cleanup) cleanup_task ;;
    status) show_status ;;
    *) usage ;;
esac
