#!/bin/bash
set -e # Exit immediately if any command fails

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."

OUTPUT_DIR="$ROOT_DIR/output"
CONFIG_DIR="$ROOT_DIR/config"

REPOSITORY_ID="geonames"
GRAPHDB_HOST="${GRAPHDB_HOST:-localhost}"
ADDRESS="http://${GRAPHDB_HOST}:7200/repositories/$REPOSITORY_ID"
REPOSITORY_CONFIG="$CONFIG_DIR/repository.ttl"

COUNTRY_CODE="${1:-DE}"           # 1st argument: Country code, default to DE
USERNAME_WITH_PASSWORD="${2:-}"  # 2nd argument: Optional "-u user:pass"

RDF_FILE="$OUTPUT_DIR/geonames_${COUNTRY_CODE}.ttl"
ONTOLOGY_FILE="$OUTPUT_DIR/ontology_v3.3.rdf"

GRAPH_GEONAMES="https://sws.geonames.org"
GRAPH_ONTOLOGY="https://www.geonames.org/ontology"

# Step 1: Delete existing repository (if any)
echo "[1/6] Removing '$REPOSITORY_ID' repository for country code: $COUNTRY_CODE."
curl -X DELETE "$ADDRESS" $USERNAME_WITH_PASSWORD || true

# Step 2: Create new repository
echo "[2/6] Creating '$REPOSITORY_ID' repository for country code: $COUNTRY_CODE."
curl -X PUT --header "Content-Type: application/x-turtle" \
  --data-binary @$REPOSITORY_CONFIG \
  "$ADDRESS" $USERNAME_WITH_PASSWORD

# Step 3: Upload RDF file(s) to GraphDB
echo "[3/6] Uploading $RDF_FILE to named graph '$GRAPH_GEONAMES'..."
curl -X POST \
  --header "Content-Type: application/x-turtle" \
  --data-binary @"$RDF_FILE" \
  "$ADDRESS/rdf-graphs/service?graph=$GRAPH_GEONAMES" \
  $USERNAME_WITH_PASSWORD

# Upload the GeoNames ontology (RDF/XML) to the repository to provide schema/vocabulary definitions.
echo "[3b/6] Uploading $ONTOLOGY_FILE to named graph '$GRAPH_ONTOLOGY'..."
curl -X POST \
  --header "Content-Type: application/rdf+xml" \
  --data-binary @"$ONTOLOGY_FILE" \
  "$ADDRESS/rdf-graphs/service?graph=$GRAPH_ONTOLOGY" \
  $USERNAME_WITH_PASSWORD

# Step 4: Refresh GeoSPARQL plugin
echo "[4/6] Refreshing GeoSPARQL plugin for '$REPOSITORY_ID'."
curl "$ADDRESS/statements" $USERNAME_WITH_PASSWORD --data-urlencode update='INSERT DATA { [] <http://www.ontotext.com/plugins/geosparql#enabled> "false" . } ; INSERT DATA { [] <http://www.ontotext.com/plugins/geosparql#enabled> "true" . }'

# Step 5: Post-upload configuration
echo "[5/6] Deleting empty namespace prefix in '$REPOSITORY_ID' repository."
curl -X DELETE --header "Content-Type: text/plain" "$ADDRESS/namespaces/" $USERNAME_WITH_PASSWORD

echo "[6/6] Enabling autocomplete index for '$REPOSITORY_ID' repository."
curl "$ADDRESS/statements" $USERNAME_WITH_PASSWORD --data-urlencode update='INSERT DATA { _:s <http://www.ontotext.com/plugins/autocomplete#enabled> true . }'

echo "RDF for country code $COUNTRY_CODE successfully uploaded to $ADDRESS"
