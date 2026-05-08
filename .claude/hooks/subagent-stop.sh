#!/usr/bin/env bash
# SubagentStop hook — verify agent completion, remove finished subagents, log to history
set -euo pipefail

input=$(cat)
agent_id=$(echo "$input" | jq -r '.agent_id // empty')
agent_transcript=$(echo "$input" | jq -r '.agent_transcript_path // empty')

# CB-A004: agent_id is required for lifecycle tracking
[ -z "$agent_id" ] && exit 0

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCRIPTS_DIR="$PROJECT_DIR/scripts"
cache_dir="$PROJECT_DIR/.claude/cache"
mkdir -p "$cache_dir"
cache_file="$cache_dir/active-agents.json"
history_file="$cache_dir/agent-history.jsonl"

# ---------------------------------------------------------------------------
# Source verification libraries (non-fatal if missing — blueprint may not be
# fully scaffolded yet)
# ---------------------------------------------------------------------------
# shellcheck source=../../../scripts/hooks/lib/verify-implementor.sh
source "${SCRIPTS_DIR}/hooks/lib/verify-implementor.sh" 2>/dev/null || true
# shellcheck source=../../../scripts/hooks/lib/verify-verifier.sh
source "${SCRIPTS_DIR}/hooks/lib/verify-verifier.sh" 2>/dev/null || true
# shellcheck source=../../../scripts/hooks/lib/verify-chronologist.sh
source "${SCRIPTS_DIR}/hooks/lib/verify-chronologist.sh" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Role detection — pattern-match against agent prompt
# ---------------------------------------------------------------------------
detect_role() {
  local prompt="$1"
  local prompt_lower
  prompt_lower=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')
  if printf '%s' "$prompt_lower" | grep -qE '(implementor|worktree.*tdd|tdd.*worktree)'; then
    printf 'implementor'
  elif printf '%s' "$prompt_lower" | grep -qE '(verifier|verify.*checklist|verification.*checklist)'; then
    printf 'verifier'
  elif printf '%s' "$prompt_lower" | grep -qE '(chronologist|implementation.log.*write|write.*implementation.log)'; then
    printf 'chronologist'
  else
    printf 'pass-through'
  fi
}

# ---------------------------------------------------------------------------
# Read agent data from active cache
# ---------------------------------------------------------------------------
agent_data=""
agent_prompt=""
role="pass-through"

if [ -f "$cache_file" ]; then
  agent_data=$(jq -c --arg id "$agent_id" '.[$id] // empty' "$cache_file" 2>/dev/null || echo "")
  if [ -n "$agent_data" ] && [ "$agent_data" != "" ]; then
    agent_prompt=$(printf '%s' "$agent_data" | jq -r '.prompt // .type // ""' 2>/dev/null || echo "")
    role=$(detect_role "$agent_prompt")
  fi
fi

# ---------------------------------------------------------------------------
# Run verification based on detected role (non-blocking — results logged only)
# ---------------------------------------------------------------------------
verification_result=""

if [ "$role" = "implementor" ] && type verify_implementor &>/dev/null; then
  plan_file=$(printf '%s' "$agent_data" | jq -r '.plan_file // ""' 2>/dev/null || echo "")
  worktree_path=$(printf '%s' "$agent_data" | jq -r '.worktree_path // ""' 2>/dev/null || echo "")
  verification_result=$(verify_implementor "$plan_file" "$worktree_path" 2>/dev/null) || true

elif [ "$role" = "verifier" ] && type verify_verifier &>/dev/null; then
  plan_id=$(printf '%s' "$agent_data" | jq -r '.plan_id // ""' 2>/dev/null || echo "")
  verification_result=$(verify_verifier "$plan_id" "$PROJECT_DIR" 2>/dev/null) || true

elif [ "$role" = "chronologist" ] && type verify_chronologist &>/dev/null; then
  plan_file=$(printf '%s' "$agent_data" | jq -r '.plan_file // ""' 2>/dev/null || echo "")
  verification_result=$(verify_chronologist "$plan_file" 2>/dev/null) || true
fi

# ---------------------------------------------------------------------------
# Record to history before removing (include role + verification result)
# ---------------------------------------------------------------------------
if [ -f "$cache_file" ]; then
  if [ -n "$agent_data" ] && [ "$agent_data" != "" ]; then
    # Build jq arguments for optional verification result
    jq_args=(
      --arg end "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      --arg tp "$agent_transcript"
      --arg rl "$role"
    )
    jq_expr='. + {ended_at: $end, transcript_path: $tp, role: $rl}'

    if [ -n "$verification_result" ]; then
      jq_args+=(--argjson vr "$verification_result")
      jq_expr='. + {ended_at: $end, transcript_path: $tp, role: $rl, verification: $vr}'
    fi

    echo "$agent_data" | jq -c "${jq_args[@]}" "$jq_expr" >> "$history_file"
  fi
fi

# ---------------------------------------------------------------------------
# Remove from active cache atomically
# ---------------------------------------------------------------------------
if [ -f "$cache_file" ]; then
  tmp=$(mktemp)
  jq --arg id "$agent_id" 'del(.[$id])' "$cache_file" > "$tmp" && mv "$tmp" "$cache_file"
fi

# Non-blocking: always exit 0 regardless of verification results
exit 0
