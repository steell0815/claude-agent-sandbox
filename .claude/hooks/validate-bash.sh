#!/bin/bash
#
# PreToolUse hook to validate Bash commands
# Blocks file operations that target paths outside the project directory
#

# Resolve project root dynamically (no placeholder dependency)
PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Read JSON input from stdin
INPUT=$(cat)

# Extract the command from the JSON
COMMAND=$(echo "$INPUT" | jq -r '.input.command // empty')

# If no command found, approve by default
if [ -z "$COMMAND" ]; then
  echo '{"decision": "approve"}'
  exit 0
fi

# Check for path traversal with ..
if echo "$COMMAND" | grep -qE '(mv|cp|rm|cat|chmod|chown)\s+.*\.\.'; then
  echo '{"decision": "block", "reason": "Path traversal (..) not allowed for file operations"}'
  exit 0
fi

# Check for operations on home directory
if echo "$COMMAND" | grep -qE '(mv|cp|rm)\s+.*~/'; then
  echo '{"decision": "block", "reason": "Operations on home directory (~/) not allowed"}'
  exit 0
fi

# Check for operations on root
if echo "$COMMAND" | grep -qE '(rm|mv)\s+(-rf?\s+)?/$'; then
  echo '{"decision": "block", "reason": "Operations on root (/) not allowed"}'
  exit 0
fi

# Check for sudo
if echo "$COMMAND" | grep -qE '^sudo\s'; then
  echo '{"decision": "block", "reason": "sudo not allowed"}'
  exit 0
fi

# Check for rm -rf with absolute paths outside project
if echo "$COMMAND" | grep -qE 'rm\s+-rf?\s+/'; then
  # Allow only if path starts with project directory
  if ! echo "$COMMAND" | grep -qE "rm\s+-rf?\s+${PROJECT_DIR}"; then
    echo '{"decision": "block", "reason": "rm -rf on absolute paths outside project not allowed"}'
    exit 0
  fi
fi

# Command is approved
echo '{"decision": "approve"}'
