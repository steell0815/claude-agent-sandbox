#!/usr/bin/env bash
# View a specific agent's transcript log
# Usage: view-agent-log.sh <agent-id | transcript-path>
set -euo pipefail

target="${1:-}"
if [ -z "$target" ]; then
  echo "Usage: view-agent-log.sh <agent-id | transcript-path>"
  exit 1
fi

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cache_dir="$PROJECT_DIR/.claude/cache"
active_file="$cache_dir/active-agents.json"
history_file="$cache_dir/agent-history.jsonl"
transcript_path=""

# If target looks like a path, use it directly
if [[ "$target" == /* || "$target" == ~/* ]]; then
  transcript_path="$target"
else
  # Search active agents by id
  if [ -f "$active_file" ]; then
    transcript_path=$(jq -r --arg id "$target" '.[$id].transcript_path // empty' "$active_file" 2>/dev/null || echo "")
  fi
  # Search history if not found in active
  if [ -z "$transcript_path" ] && [ -f "$history_file" ]; then
    transcript_path=$(grep "$target" "$history_file" 2>/dev/null | tail -1 | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
  fi
fi

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
  echo "Agent transcript not found for: $target"
  echo "Available agent IDs:"
  if [ -f "$active_file" ]; then
    echo "  Active:"
    jq -r 'keys[] | "    " + .' "$active_file" 2>/dev/null || true
  fi
  if [ -f "$history_file" ]; then
    echo "  History (last 10):"
    tail -10 "$history_file" 2>/dev/null | jq -r '"    " + .id' 2>/dev/null || true
  fi
  exit 1
fi

echo "=== AGENT LOG: $target ==="
echo "Transcript: $transcript_path"
echo ""

jq -r '
  if .role then
    "[\(.role | ascii_upcase)] " + (
      if .content | type == "string" then .content
      elif .content | type == "array" then
        [.content[] |
          if .type == "text" then .text
          elif .type == "tool_use" then "Tool: \(.name)(\(.input | tostring | .[0:200]))"
          elif .type == "tool_result" then "Result: \(.content // .output // "" | tostring | .[0:300])"
          else .type
          end
        ] | join("\n  ")
      else .content | tostring | .[0:500]
      end
    )
  else empty
  end
' "$transcript_path" 2>/dev/null || cat "$transcript_path"
