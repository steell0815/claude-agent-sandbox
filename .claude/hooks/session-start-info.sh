#!/usr/bin/env bash
# SessionStart hook — display environment summary at session start
set -euo pipefail

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Count hooks
hook_count=0
if [[ -f "$PROJECT_DIR/.claude/settings.json" ]]; then
  hook_count=$(python3 -c "
import json
d=json.load(open('$PROJECT_DIR/.claude/settings.json'))
h=d.get('hooks',{})
print(sum(len(v) for v in h.values()))
" 2>/dev/null || echo 0)
fi

# Count project skills
skill_count=0
if [[ -d "$PROJECT_DIR/.claude/skills" ]]; then
  skill_count=$(find "$PROJECT_DIR/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
fi

# Count MCP servers
mcp_count=0
for f in "$PROJECT_DIR/.claude/settings.json" "$PROJECT_DIR/.mcp.json"; do
  if [[ -f "$f" ]]; then
    c=$(python3 -c "import json; print(len(json.load(open('$f')).get('mcpServers',{})))" 2>/dev/null || echo 0)
    mcp_count=$((mcp_count + c))
  fi
done

# Git info
branch=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "detached")
today_commits=$(git -C "$PROJECT_DIR" log --oneline --since="midnight" 2>/dev/null | wc -l | tr -d ' ')

cat << EOF
Session environment: ${hook_count} hook(s), ${skill_count} skill(s), ${mcp_count} MCP server(s). Branch: ${branch}, ${today_commits} commit(s) today.
EOF
