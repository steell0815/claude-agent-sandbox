#!/usr/bin/env bash
# render-readiness-bar.sh — Render a visual bar for a readiness dimension
#
# Usage:
#   render-readiness-bar.sh "<dimension-name>" <score>
#
# Output: Formatted bar line
#   Cognitive Complexity     4 ■■■■□  ⚠

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <dimension-name> <score>" >&2
  exit 1
fi

NAME="$1"
SCORE="$2"

PADDED=$(printf "%-24s" "$NAME")

FILLED=""
EMPTY=""
for ((i = 0; i < SCORE; i++)); do
  FILLED+="■"
done
for ((i = SCORE; i < 5; i++)); do
  EMPTY+="□"
done

WARNING=""
if [[ $SCORE -ge 4 ]]; then
  WARNING="  ⚠"
fi

echo "${PADDED} ${SCORE} ${FILLED}${EMPTY}${WARNING}"
