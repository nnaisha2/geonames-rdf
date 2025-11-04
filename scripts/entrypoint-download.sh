#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default to DE if no argument is passed
COUNTRY_CODE="${1:-DE}"
echo "[DOWNLOAD] Starting download for country code: $COUNTRY_CODE ..."

# Call the download script
source "$SCRIPT_DIR/download.sh" "$COUNTRY_CODE"

echo "[DOWNLOAD] Done."