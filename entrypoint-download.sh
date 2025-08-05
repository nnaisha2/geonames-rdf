#!/bin/bash
set -e

# Default to DE if no argument is passed
COUNTRY_CODE="${1:-DE}"
echo "[DOWNLOAD] Starting download for country code: $COUNTRY_CODE ..."

# Call the download script
source ./download.sh "$COUNTRY_CODE"

echo "[DOWNLOAD] Done."