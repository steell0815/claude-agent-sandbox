#!/usr/bin/env bash
# get-readiness-band.sh — Map a composite readiness score to a band and label
#
# Usage:
#   get-readiness-band.sh <composite>
#
# Output: JSON with band and label
#   {"band": "BLUE", "label": "Manageable"}

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <composite-score>" >&2
  exit 1
fi

COMPOSITE="$1"

# Compare using bc; result is 1 (true) or 0 (false)
if [[ $(echo "$COMPOSITE <= 1.7" | bc -l) -eq 1 ]]; then
  BAND="GREEN"
  LABEL="Straightforward"
elif [[ $(echo "$COMPOSITE <= 2.5" | bc -l) -eq 1 ]]; then
  BAND="BLUE"
  LABEL="Manageable"
elif [[ $(echo "$COMPOSITE <= 3.5" | bc -l) -eq 1 ]]; then
  BAND="YELLOW"
  LABEL="Complex"
elif [[ $(echo "$COMPOSITE <= 4.5" | bc -l) -eq 1 ]]; then
  BAND="ORANGE"
  LABEL="High complexity"
else
  BAND="RED"
  LABEL="Extreme"
fi

echo "{\"band\": \"$BAND\", \"label\": \"$LABEL\"}"
