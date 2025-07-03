#!/bin/bash
set -e # Exit immediately if any command fails
echo "GRAPHDB_HOST is: $GRAPHDB_HOST"

# Configuration
OUTPUT_DIR="$PWD/output"
CONFIG_DIR="$PWD/config"
REPOSITORY_ID="geonames"
GRAPHDB_HOST="${GRAPHDB_HOST:-localhost}"
ADDRESS="http://${GRAPHDB_HOST}:7200/repositories/$REPOSITORY_ID"
USERNAME_WITH_PASSWORD=""  # Optional: -u user:pass
REPOSITORY_CONFIG="$CONFIG_DIR/repository.ttl"

COUNTRY_CODE="${1:-DE}"  # Accept country code as argument, default to DE
RDF_FILE="$OUTPUT_DIR/geonames_${COUNTRY_CODE}.ttl"

# Step 1: Delete existing repository (if any)
echo "[1/6] Removing '$REPOSITORY_ID' repository for country code: $COUNTRY_CODE."
curl -X DELETE "$ADDRESS" $USERNAME_WITH_PASSWORD || true

# Step 2: Create new repository
echo "[2/6] Creating '$REPOSITORY_ID' repository for country code: $COUNTRY_CODE."
curl -X PUT --header "Content-Type: application/x-turtle" \
  --data-binary @$REPOSITORY_CONFIG \
  "$ADDRESS" $USERNAME_WITH_PASSWORD

# Step 3: Upload RDF file(s) to GraphDB
echo "[3/6] Uploading $RDF_FILE to GraphDB..."
curl -X POST --header "Content-Type: application/x-turtle" \
  --data-binary @$RDF_FILE \
  "$ADDRESS/statements" $USERNAME_WITH_PASSWORD

# Upload the GeoNames ontology (RDF/XML) to the repository to provide schema/vocabulary definitions.
echo "[3b/6] Uploading ontology_v3.3.rdf to GraphDB..."
curl -X POST --header "Content-Type: application/rdf+xml" \
  --data-binary @"$OUTPUT_DIR/ontology_v3.3.rdf" \
  "$ADDRESS/statements" $USERNAME_WITH_PASSWORD

# Step 4: Refresh GeoSPARQL plugin
echo "[4/6] Refreshing GeoSPARQL plugin for '$REPOSITORY_ID'."
curl "$ADDRESS/statements" $USERNAME_WITH_PASSWORD --data-urlencode update='INSERT DATA { [] <http://www.ontotext.com/plugins/geosparql#enabled> "false" . } ; INSERT DATA { [] <http://www.ontotext.com/plugins/geosparql#enabled> "true" . }'

# Step 5: Post-upload configuration
echo "[5/6] Deleting empty namespace prefix in '$REPOSITORY_ID' repository."
curl -X DELETE --header "Content-Type: text/plain" "$ADDRESS/namespaces/" $USERNAME_WITH_PASSWORD

echo "[6/6] Enabling autocomplete index for '$REPOSITORY_ID' repository."
curl "$ADDRESS/statements" $USERNAME_WITH_PASSWORD --data-urlencode update='INSERT DATA { _:s <http://www.ontotext.com/plugins/autocomplete#enabled> true . }'

echo "RDF for country code $COUNTRY_CODE uploaded to $ADDRESS"
