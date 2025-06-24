#!/bin/bash
set -e # Exit immediately if any command fails

OUTPUT_DIR="$PWD/output"
CONFIG_DIR="$PWD/config"
REPOSITORY_ID="geonames"
ADDRESS="http://localhost:7200/repositories/$REPOSITORY_ID"
USERNAME_WITH_PASSWORD=""  # Optional: -u user:pass
REPOSITORY_CONFIG="$CONFIG_DIR/repository.ttl"

# Step 1: Delete existing repository (if any)
echo "[1/6] Removing '$REPOSITORY_ID' repository."
curl -X DELETE "$ADDRESS" $USERNAME_WITH_PASSWORD || true

# Step 2: Create new repository
echo "[2/6] Creating '$REPOSITORY_ID' repository."
curl -X PUT --header "Content-Type: application/x-turtle" \
  --data-binary @$REPOSITORY_CONFIG \
  "$ADDRESS" $USERNAME_WITH_PASSWORD

# Step 3: Upload RDF file(s) to GraphDB
echo "[3/6] Uploading geonames.ttl to GraphDB..."
curl -X POST --header "Content-Type: application/x-turtle" \
  --data-binary @$OUTPUT_DIR/geonames.ttl \
  "$ADDRESS/statements" $USERNAME_WITH_PASSWORD

# Step 4: Refresh GeoSPARQL plugin
echo "[4/6] Refreshing GeoSPARQL plugin..."
curl "$ADDRESS/statements" $USERNAME_WITH_PASSWORD --data-urlencode update='INSERT DATA { [] <http://www.ontotext.com/plugins/geosparql#enabled> "false" . } ; INSERT DATA { [] <http://www.ontotext.com/plugins/geosparql#enabled> "true" . }'

# Step 5: Post-upload configuration
echo "[5/5] Deleting empty namespace prefix in '$REPOSITORY_ID' repository."
curl -X DELETE --header "Content-Type: text/plain" "$ADDRESS/namespaces/" $USERNAME_WITH_PASSWORD

echo "[6/6] Enabling autocomplete index for '$REPOSITORY_ID' repository."
curl "$ADDRESS/statements" $USERNAME_WITH_PASSWORD --data-urlencode update='INSERT DATA { _:s <http://www.ontotext.com/plugins/autocomplete#enabled> true . }'

echo "RDF uploaded to $ADDRESS"
