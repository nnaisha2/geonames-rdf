#!/bin/bash
set -e

COUNTRY_CODE="${1:-DE}"
UPLOAD=${UPLOAD:-true}
UPLOAD_QENDPOINT=${UPLOAD_QENDPOINT:-false}
QENDPOINT_HOST=${QENDPOINT_HOST:-qendpoint}
QENDPOINT_PORT=1234
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[UPLOAD] Starting upload for country code: $COUNTRY_CODE ..."

if [ "$UPLOAD_QENDPOINT" = "true" ]; then
  echo "[UPLOAD] Waiting for qEndpoint at $QENDPOINT_HOST:$QENDPOINT_PORT..."
  until curl -s "http://$QENDPOINT_HOST:$QENDPOINT_PORT/" > /dev/null; do
    echo "Waiting for qEndpoint to be ready..."
    sleep 5
  done
  echo "[3a/3] Uploading to qEndpoint ..."
  source "$SCRIPT_DIR/upload_to_qendpoint.sh" "$COUNTRY_CODE"

elif [ "$UPLOAD_GRAPHDB" = "true" ]; then
  echo "[UPLOAD] Waiting for GraphDB at $GRAPHDB_HOST:7200 to be ready..."
  until curl -s "http://graphdb:7200" > /dev/null; do
    echo "[UPLOAD] GraphDB is not ready yet. Retrying in 5 seconds..."
    sleep 5
  done
  echo "[3b/3] Uploading to GraphDB ..."
  source "$SCRIPT_DIR/../graphdb/upload_to_graphdb.sh" "$COUNTRY_CODE"
else
  echo "No upload target specified. Skipping upload."
fi

echo "[UPLOAD] Completed."
