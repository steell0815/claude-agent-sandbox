#!/usr/bin/env bash
# check-secrets.sh — Detect hardcoded secrets in staged diff
#
# Provides: run_check_secrets()
# Returns: 0 = clean, 1 = secrets found

set -euo pipefail

run_check_secrets() {
  local diff_output
  diff_output=$(git diff --cached -U0 || true)

  if [[ -z "$diff_output" ]]; then
    printf '  \xe2\x9c\x93 [CB-H011] No staged changes to scan\n'
    return 0
  fi

  local secrets_found=0
  local current_file=""
  local line_num=0

  while IFS= read -r line; do
    # Track current file from diff header
    if [[ "$line" =~ ^diff\ --git\ a/(.+)\ b/ ]]; then
      current_file="${BASH_REMATCH[1]}"
      line_num=0
      continue
    fi

    # Skip excluded file types and test fixture directories
    if [[ "$current_file" =~ \.(test|spec|fixture)\. ]] \
      || [[ "$current_file" =~ \.md$ ]] \
      || [[ "$current_file" =~ (^|/)scripts/tests/ ]] \
      || [[ "$current_file" =~ (^|/)tests?/fixtures/ ]]; then
      continue
    fi

    # Track line numbers from hunk headers
    if [[ "$line" =~ ^@@\ -[0-9]+(,[0-9]+)?\ \+([0-9]+) ]]; then
      line_num="${BASH_REMATCH[2]}"
      continue
    fi

    # Only scan added lines
    if [[ "$line" =~ ^\+ ]] && [[ ! "$line" =~ ^\+\+\+ ]]; then
      local added_content="${line:1}"

      # AWS Access Key
      if [[ "$added_content" =~ AKIA[0-9A-Z]{16} ]]; then
        secrets_found=1
        printf '  \xe2\x9c\x97 [CB-H011] Secret detected: %s:%d \xe2\x80\x94 AWS key pattern\n' "$current_file" "$line_num"
      fi

      # GitHub Personal Access Token
      if [[ "$added_content" =~ ghp_[a-zA-Z0-9]{36} ]]; then
        secrets_found=1
        printf '  \xe2\x9c\x97 [CB-H011] Secret detected: %s:%d \xe2\x80\x94 GitHub token pattern\n' "$current_file" "$line_num"
      fi

      # Generic secrets (case insensitive via bash)
      local lower_content
      lower_content=$(printf '%s' "$added_content" | tr '[:upper:]' '[:lower:]')
      if [[ "$lower_content" =~ (password|secret|api[_-]?key|token|private[_-]?key)[[:space:]]*[:=][[:space:]]*[\"\'][^\"\'][^\"\'][^\"\'][^\"\'][^\"\'][^\"\'][^\"\'][^\"\'] ]]; then
        secrets_found=1
        printf '  \xe2\x9c\x97 [CB-H011] Secret detected: %s:%d \xe2\x80\x94 generic secret pattern\n' "$current_file" "$line_num"
      fi

      line_num=$((line_num + 1))
    fi
  done <<< "$diff_output"

  if [[ "$secrets_found" -eq 0 ]]; then
    printf '  \xe2\x9c\x93 [CB-H011] No hardcoded secrets detected\n'
  fi

  return "$secrets_found"
}
