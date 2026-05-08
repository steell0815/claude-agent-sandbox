#!/usr/bin/env bash
# check-bash-syntax.sh — Validate staged .sh files with bash -n and shellcheck
#
# Provides: run_check_bash_syntax()
# Returns: 0 = all pass, 1 = syntax or lint errors found

set -euo pipefail

run_check_bash_syntax() {
  local staged_files
  staged_files=$(git diff --cached --name-only --diff-filter=ACM -- '*.sh' || true)

  if [[ -z "$staged_files" ]]; then
    printf '  \xe2\x9c\x93 [CB-H012] No staged .sh files to check\n'
    return 0
  fi

  local errors_found=0
  local file

  # Phase 1: bash -n syntax check
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    local err_file
    err_file=$(mktemp)
    if ! bash -n "$file" 2>"$err_file"; then
      errors_found=1
      while IFS= read -r err_line; do
        printf '  \xe2\x9c\x97 [CB-H012] %s: %s\n' "$file" "$err_line"
      done < "$err_file"
    fi
    rm -f "$err_file"
  done <<< "$staged_files"

  # Phase 2: shellcheck lint (if available)
  if command -v shellcheck &>/dev/null; then
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue

      local sc_out
      sc_out=$(mktemp)
      if ! shellcheck -S warning -x "$file" > "$sc_out" 2>&1; then
        errors_found=1
        while IFS= read -r sc_line; do
          [[ -z "$sc_line" ]] && continue
          printf '  \xe2\x9c\x97 [CB-H013] %s\n' "$sc_line"
        done < "$sc_out"
      fi
      rm -f "$sc_out"
    done <<< "$staged_files"

    if [[ "$errors_found" -eq 0 ]]; then
      printf '  \xe2\x9c\x93 [CB-H012] All staged .sh files pass syntax + shellcheck\n'
    fi
  else
    if [[ "$errors_found" -eq 0 ]]; then
      printf '  \xe2\x9c\x93 [CB-H012] All staged .sh files pass syntax check (shellcheck not available)\n'
    fi
  fi

  return "$errors_found"
}
