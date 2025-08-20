#!/bin/bash
set -e

# Usage:
#   ./upload_to_qendpoint.sh [COUNTRY_CODE]
# or with custom files:
#   ./upload_to_qendpoint.sh [DATA_RDF_FILE] [ONTOLOGY_RDF_FILE] [QENDPOINT_URL]

OUTPUT_DIR="${OUTPUT_DIR:-$PWD/output}"
CONFIG_DIR="${CONFIG_DIR:-$PWD/config}"
COUNTRY_CODE="${1:-DE}"

DATA_RDF_FILE="${2:-$OUTPUT_DIR/geonames_${COUNTRY_CODE}.ttl}"
ONTOLOGY_RDF_FILE="${3:-$OUTPUT_DIR/ontology_v3.3.rdf}"

QENDPOINT_HOST="${QENDPOINT_HOST:-localhost}"
QENDPOINT_PORT="${QENDPOINT_PORT:-1234}"
QENDPOINT_URL="${4:-http://$QENDPOINT_HOST:$QENDPOINT_PORT}"

# Upload function
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

# Start process
echo "[Step 1/4] Upload Ontology RDF"
upload_file "$ONTOLOGY_RDF_FILE"

echo "[Step 2/4] Upload Data RDF"
upload_file "$DATA_RDF_FILE"

echo "[Step 3/4] Trigger MERGE operation"
trigger_merge

echo "[Step 4/4] Poll MERGE status and wait for completion"
wait_for_merge_completion

echo "Upload and merge process completed successfully."