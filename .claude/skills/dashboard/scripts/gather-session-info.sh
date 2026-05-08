#!/usr/bin/env bash
# Gathers current Claude Code session environment info
set -euo pipefail

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== SESSION DASHBOARD ==="
echo ""

# --- Settings ---
echo "## Project Settings"
if [[ -f "$PROJECT_DIR/.claude/settings.json" ]]; then
  cat "$PROJECT_DIR/.claude/settings.json"
else
  echo "(no settings.json found)"
fi
echo ""

# --- Hooks ---
echo "## Configured Hooks"
if [[ -f "$PROJECT_DIR/.claude/settings.json" ]]; then
  python3 -c "
import json
d=json.load(open('$PROJECT_DIR/.claude/settings.json'))
h=d.get('hooks',{})
for k,v in h.items():
    print(f'  {k}: {len(v)} rule(s)')
" 2>/dev/null || echo "  (could not parse)"
fi
echo ""

# --- Skills ---
echo "## Project Skills"
if [[ -d "$PROJECT_DIR/.claude/skills" ]]; then
  for skill_dir in "$PROJECT_DIR/.claude/skills"/*/; do
    if [[ -f "${skill_dir}SKILL.md" ]]; then
      name=$(basename "$skill_dir")
      desc=$(grep -m1 'description:' "${skill_dir}SKILL.md" 2>/dev/null | sed 's/description: *//' || echo "")
      echo "  /${name} — ${desc}"
    fi
  done
else
  echo "  (none)"
fi
echo ""

# --- MCP Servers ---
echo "## MCP Servers"
for f in "$PROJECT_DIR/.claude/settings.json" "$PROJECT_DIR/.mcp.json"; do
  if [[ -f "$f" ]]; then
    python3 -c "
import json
d=json.load(open('$f'))
servers=d.get('mcpServers',{})
for name,cfg in servers.items():
    cmd=cfg.get('command','')
    print(f'  {name} ({cmd})')
" 2>/dev/null || true
  fi
done
echo ""

# --- Active Agents ---
echo "## Active Agents"
cache_file="$PROJECT_DIR/.claude/cache/active-agents.json"
if [ -f "$cache_file" ] && [ "$(jq 'length' "$cache_file" 2>/dev/null)" -gt 0 ] 2>/dev/null; then
  jq -r '.[] | "  [\(.id)] \(.type) — started \(.started_at)"' "$cache_file"
else
  echo "  (none)"
fi
echo ""

# --- Git State ---
echo "## Git State"
echo "  Branch: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo 'detached')"
echo "  Last commit: $(git -C "$PROJECT_DIR" log -1 --format='%ar — %s' 2>/dev/null || echo 'none')"
echo "  Today's commits: $(git -C "$PROJECT_DIR" log --oneline --since=midnight 2>/dev/null | wc -l | tr -d ' ')"
echo "  Uncommitted changes: $(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ') file(s)"
echo ""

# --- Plans ---
echo "## Plans"
if [[ -f "$PROJECT_DIR/plans/index.json" ]]; then
  python3 -c "
import json
d=json.load(open('$PROJECT_DIR/plans/index.json'))
for p in d.get('plans',[]):
    if p.get('status') in ('planned','in_progress'):
        print(f\"  [{p['status']}] {p['title']}\")
" 2>/dev/null || echo "  (could not parse)"
else
  echo "  (no plans index)"
fi
echo ""

echo "=== END DASHBOARD ==="
