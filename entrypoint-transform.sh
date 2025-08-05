#!/bin/bash
set -e

COUNTRY_CODE="${1:-DE}"
echo "[TRANSFORM] Starting RDF transformation for: $COUNTRY_CODE ..."

# Call the transformation script
source ./map.sh "$COUNTRY_CODE"

echo "[TRANSFORM] Done."
