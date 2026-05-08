#!/usr/bin/env bash
# Claude Code status line — session stats + capabilities + git state

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')
agent_name=$(echo "$input" | jq -r '.agent.name // empty')
worktree_name=$(echo "$input" | jq -r '.worktree.name // empty')

# --- Line 1: Session stats ---
parts=()

[ -n "$model" ] && parts+=("$model")

if [ -n "$cwd" ]; then
  short_cwd="${cwd/#$HOME/~}"
  parts+=("$short_cwd")
fi

if [ -n "$used_pct" ]; then
  ctx=$(printf "ctx:%.0f%%" "$used_pct")
  parts+=("$ctx")
fi

if [ -n "$cost" ]; then
  cost_fmt=$(printf '$%.4f' "$cost")
  parts+=("$cost_fmt")
fi

if [ -n "$lines_added" ] || [ -n "$lines_removed" ]; then
  delta=""
  [ -n "$lines_added" ] && [ "$lines_added" != "0" ] && delta="+${lines_added}"
  [ -n "$lines_removed" ] && [ "$lines_removed" != "0" ] && delta="${delta:+$delta/}-${lines_removed}"
  [ -n "$delta" ] && parts+=("lines:$delta")
fi

if [ ${#parts[@]} -gt 0 ]; then
  printf '%s' "${parts[0]}"
  for part in "${parts[@]:1}"; do
    printf ' | %s' "$part"
  done
fi

# --- Line 2: Active agents & capabilities ---
echo ""

cap_parts=()

[ -n "$agent_name" ] && cap_parts+=("agent:$agent_name")
[ -n "$worktree_name" ] && cap_parts+=("worktree:$worktree_name")

# Running subagents from cache
PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
agents_cache="$PROJECT_DIR/.claude/cache/active-agents.json"
if [ -f "$agents_cache" ]; then
  agent_count=$(jq 'length' "$agents_cache" 2>/dev/null || echo 0)
  if [ "$agent_count" -gt 0 ] 2>/dev/null; then
    agent_names=$(jq -r '[.[] | .type] | join(",")' "$agents_cache" 2>/dev/null)
    cap_parts+=("subagents:${agent_count}[${agent_names}]")
  fi
fi

# Count project skills
if [ -d "$PROJECT_DIR/.claude/skills" ]; then
  skill_count=$(find "$PROJECT_DIR/.claude/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
  [ "$skill_count" -gt 0 ] 2>/dev/null && cap_parts+=("skills:$skill_count")
fi

if [ ${#cap_parts[@]} -gt 0 ]; then
  printf '%s' "${cap_parts[0]}"
  for part in "${cap_parts[@]:1}"; do
    printf ' | %s' "$part"
  done
fi

# --- Line 3: Git status ---
git_dir="${cwd:-.}"
if git -C "$git_dir" rev-parse --is-inside-work-tree &>/dev/null; then
  echo ""
  git_parts=()

  branch=$(git -C "$git_dir" symbolic-ref --short HEAD 2>/dev/null || echo "detached")
  git_parts+=("$branch")

  upstream=$(git -C "$git_dir" rev-parse --abbrev-ref "${branch}@{upstream}" 2>/dev/null || echo "")
  if [ -n "$upstream" ]; then
    behind=$(git -C "$git_dir" rev-list --count HEAD.."${branch}@{upstream}" 2>/dev/null || echo 0)
    ahead=$(git -C "$git_dir" rev-list --count "${branch}@{upstream}"..HEAD 2>/dev/null || echo 0)
    git_parts+=("↓${behind:-0}")
    git_parts+=("↑${ahead:-0}")
  fi

  rev=$(git -C "$git_dir" rev-parse --short HEAD 2>/dev/null || echo "")
  [ -n "$rev" ] && git_parts+=("$rev")

  printf '%s' "${git_parts[0]}"
  for part in "${git_parts[@]:1}"; do
    printf ' %s' "$part"
  done
fi
