#!/usr/bin/env bash
# calculate-readiness-composite.sh — Compute geometric mean of 8 readiness dimension scores
#
# Usage:
#   calculate-readiness-composite.sh <d1> <d2> <d3> <d4> <d5> <d6> <d7> <d8>
#
# Each score is an integer 1-5. Output is JSON:
#   {"composite": 1.86, "band": "BLUE", "label": "Manageable"}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -ne 8 ]]; then
  echo "Usage: $0 <d1> <d2> <d3> <d4> <d5> <d6> <d7> <d8>" >&2
  echo "Each dimension score must be an integer 1-5." >&2
  exit 1
fi

PRODUCT=$(echo "$1 * $2 * $3 * $4 * $5 * $6 * $7 * $8" | bc)
COMPOSITE=$(echo "scale=10; e(l($PRODUCT)/8)" | bc -l)
# Round to 2 decimal places using bc (avoids locale issues with printf)
COMPOSITE_ROUNDED=$(echo "scale=2; ($COMPOSITE * 100 + 0.5) / 100" | bc -l | sed 's/^\./0./')

BAND_JSON=$("$SCRIPT_DIR/get-readiness-band.sh" "$COMPOSITE_ROUNDED")
BAND="${BAND_JSON/*\"band\": \"/}"
BAND="${BAND/\"*/}"
LABEL="${BAND_JSON/*\"label\": \"/}"
LABEL="${LABEL/\"*/}"

echo "{\"composite\": $COMPOSITE_ROUNDED, \"band\": \"$BAND\", \"label\": \"$LABEL\"}"
