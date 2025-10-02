#!/bin/bash

set -e

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output}"
CONFIG_DIR="${CONFIG_DIR:-$ROOT_DIR/config}"
COUNTRY_CODE="${1:-DE}"
DATA_RDF_FILE="${2:-$OUTPUT_DIR/geonames_${COUNTRY_CODE}_merged.ttl}"
QENDPOINT_HOST="${QENDPOINT_HOST:-localhost}"
QENDPOINT_PORT="${QENDPOINT_PORT:-1234}"
QENDPOINT_URL="${4:-http://$QENDPOINT_HOST:$QENDPOINT_PORT}"

# Helper functions
upload_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "File not found: $file"
    exit 1
  fi
  echo "Uploading $file to $QENDPOINT_URL/api/endpoint/load ..."
  curl -f -X POST "$QENDPOINT_URL/api/endpoint/load" \
    -F "file=@$file"
  echo "Upload of $file complete."
}

trigger_merge() {
  echo "Triggering MERGE at $QENDPOINT_URL/api/endpoint/merge ..."
  curl -f -X GET "$QENDPOINT_URL/api/endpoint/merge"
  echo "Merge triggered."
}

wait_for_merge_completion() {
  echo "Waiting for MERGE to complete ..."
  while true; do
    IS_MERGING=$(curl -s "$QENDPOINT_URL/api/endpoint/is_merging" | tr -d '\r\n"')
    if [ "$IS_MERGING" != "true" ]; then
      echo "Merge completed."
      break
    else
      echo "Merge in progress... waiting 5 seconds."
      sleep 5
    fi
  done
}

# Step 1: Upload RDF file
echo "[Step 1/3] Upload Data RDF"
upload_file "$DATA_RDF_FILE"

# Step 2: Trigger MERGE
echo "[Step 2/3] Trigger MERGE operation"
trigger_merge

# Step 3: Wait for MERGE completion
echo "[Step 3/3] Poll MERGE status and wait for completion"
wait_for_merge_completion

echo "Upload and merge process completed successfully."