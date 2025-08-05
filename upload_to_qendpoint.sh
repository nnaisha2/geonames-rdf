#!/bin/bash
set -e

# Usage:
#   ./upload_to_qendpoint.sh [COUNTRY_CODE]
# or with custom files:
#   ./upload_to_qendpoint.sh [DATA_RDF_FILE] [ONTOLOGY_RDF_FILE] [QENDPOINT_URL]

OUTPUT_DIR="${OUTPUT_DIR:-$PWD/output}"
CONFIG_DIR="${CONFIG_DIR:-$PWD/config}"
COUNTRY_CODE="${1:-DE}"

# Accept custom file paths if provided
DATA_RDF_FILE="${2:-$OUTPUT_DIR/geonames_${COUNTRY_CODE}.ttl}"
ONTOLOGY_RDF_FILE="${3:-$OUTPUT_DIR/ontology_v3.3.rdf}"

# Endpoint URL (default: http://localhost:1234)
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

upload_file "$ONTOLOGY_RDF_FILE"
upload_file "$DATA_RDF_FILE"
echo " Successfully uploaded RDF to qEndpoint at $QENDPOINT_URL"