#!/usr/bin/env bash
# commit-msg.sh — Validate commit message against conventional commit format
#
# Usage: commit-msg.sh <commit-msg-file>
#
# Pattern: type(scope)?!?: lowercase subject
# Allowed types: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert
# Max first-line length: 72 characters
# Merge and revert commits are allowed as-is.
# Co-Authored-By trailer lines are ignored during validation.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  printf 'Usage: commit-msg.sh <commit-msg-file>\n' >&2
  exit 1
fi

MSG_FILE="$1"

if [[ ! -f "$MSG_FILE" ]]; then
  printf 'Error: commit message file not found: %s\n' "$MSG_FILE" >&2
  exit 1
fi

# Read just the first line (subject)
SUBJECT=$(head -n 1 "$MSG_FILE")

# Allow merge commits
if [[ "$SUBJECT" =~ ^Merge\  ]]; then
  exit 0
fi

# Allow revert commits
if [[ "$SUBJECT" =~ ^Revert\ \" ]]; then
  exit 0
fi

# Check max length (72 characters)
if [[ ${#SUBJECT} -gt 72 ]]; then
  printf '[CB-H020] Error: commit subject exceeds 72 characters (%d)\n' "${#SUBJECT}" >&2
  printf 'Subject: %s\n' "$SUBJECT" >&2
  exit 1
fi

# Validate conventional commit format
CONVENTIONAL_PATTERN='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?: .+'
if [[ ! "$SUBJECT" =~ $CONVENTIONAL_PATTERN ]]; then
  printf '[CB-H020] Error: commit message does not follow conventional commit format\n' >&2
  printf 'Expected: type(scope)?: description\n' >&2
  printf 'Types: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert\n' >&2
  printf 'Got: %s\n' "$SUBJECT" >&2
  exit 1
fi

# Extract the description part (after "type(scope)?: ")
DESCRIPTION="${SUBJECT#*: }"

# Check that description starts with lowercase
FIRST_CHAR="${DESCRIPTION:0:1}"
if [[ "$FIRST_CHAR" =~ [A-Z] ]]; then
  printf '[CB-H020] Error: commit description must start with a lowercase letter\n' >&2
  printf 'Got: %s\n' "$SUBJECT" >&2
  exit 1
fi

# Check that description is not empty (pattern already requires .+ but be explicit)
if [[ -z "${DESCRIPTION// /}" ]]; then
  printf '[CB-H020] Error: commit description must not be empty\n' >&2
  exit 1
fi

exit 0
