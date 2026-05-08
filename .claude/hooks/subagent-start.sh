#!/usr/bin/env bash
# SubagentStart hook — track active subagents in a cache file
set -euo pipefail

input=$(cat)
agent_id=$(echo "$input" | jq -r '.agent_id // empty')
agent_type=$(echo "$input" | jq -r '.agent_type // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

[ -z "$agent_id" ] && exit 0

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cache_dir="$PROJECT_DIR/.claude/cache"
mkdir -p "$cache_dir"
cache_file="$cache_dir/active-agents.json"

# Initialize cache if missing
[ ! -f "$cache_file" ] && echo '{}' > "$cache_file"

# Add agent atomically (tmpfile + mv)
tmp=$(mktemp)
jq --arg id "$agent_id" \
   --arg type "$agent_type" \
   --arg sid "$session_id" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg tp "$transcript_path" \
   '.[$id] = {id: $id, type: $type, session_id: $sid, started_at: $ts, transcript_path: $tp}' \
   "$cache_file" > "$tmp" && mv "$tmp" "$cache_file"
