#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COUNTRY_CODE="${1:-DE}"
echo "[TRANSFORM] Starting RDF transformation for: $COUNTRY_CODE ..."

# Call the transformation script
source "$SCRIPT_DIR//map.sh" "$COUNTRY_CODE"

echo "[TRANSFORM] Done."
