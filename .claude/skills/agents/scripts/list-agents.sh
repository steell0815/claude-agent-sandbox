#!/usr/bin/env bash
# List active and recent agents with their details
set -euo pipefail

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cache_dir="$PROJECT_DIR/.claude/cache"
active_file="$cache_dir/active-agents.json"
history_file="$cache_dir/agent-history.jsonl"

echo "=== ACTIVE AGENTS ==="
if [ -f "$active_file" ] && [ "$(jq 'length' "$active_file" 2>/dev/null)" -gt 0 ] 2>/dev/null; then
  jq -r '.[] | "  [\(.id)] type=\(.type) started=\(.started_at) transcript=\(.transcript_path // "n/a")"' "$active_file"
else
  echo "  (none)"
fi

echo ""
echo "=== RECENT AGENT HISTORY (last 20) ==="
if [ -f "$history_file" ]; then
  tail -20 "$history_file" | jq -r '"  [\(.id)] type=\(.type) started=\(.started_at) ended=\(.ended_at) transcript=\(.transcript_path // "n/a")"' 2>/dev/null || echo "  (parse error)"
else
  echo "  (no history)"
fi
