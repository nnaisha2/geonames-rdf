#!/bin/bash
set -e

DATA_DIR="$PWD/data"
OUTPUT_DIR="$PWD/output"
BIN_DIR="$PWD/bin"
CONFIG_DIR="$PWD/config"
REPOSITORY_ID="geonames"
ADDRESS="http://localhost:7200/repositories/$REPOSITORY_ID"
USERNAME_WITH_PASSWORD=""  # Optional: -u user:pass
REPOSITORY_CONFIG="$CONFIG_DIR/repository.ttl"

# Step 1: Download GeoNames data
echo "[1/6] Running download.sh..."
source ./download.sh

# Step 2: Transform data to RDF
echo "[2/6] Running map.sh..."
source ./map.sh

# Step 3: Delete existing repository (if any)
echo "[3/6] Removing '$REPOSITORY_ID' repository."
curl -X DELETE "$ADDRESS" $USERNAME_WITH_PASSWORD || true

# Step 4: Create new repository
echo "[4/6] Creating '$REPOSITORY_ID' repository."
curl -X PUT --header "Content-Type: application/x-turtle" \
  --data-binary @$REPOSITORY_CONFIG \
  "$ADDRESS" $USERNAME_WITH_PASSWORD

# Step 5: Upload RDF file(s) to GraphDB
echo "[5/6] Uploading geonames.ttl to GraphDB..."
curl -X POST --header "Content-Type: application/x-turtle" \
  --data-binary @$OUTPUT_DIR/geonames.ttl \
  "$ADDRESS/statements" $USERNAME_WITH_PASSWORD


# Step 6: Refresh GeoSPARQL plugin
echo "[6/6] Refreshing GeoSPARQL plugin..."
curl "$ADDRESS/statements" $USERNAME_WITH_PASSWORD --data-urlencode update='INSERT DATA { [] <http://www.ontotext.com/plugins/geosparql#enabled> "false" . } ; INSERT DATA { [] <http://www.ontotext.com/plugins/geosparql#enabled> "true" . }'

# Remove empty namespace prefix
echo "Deleting empty namespace prefix in '$REPOSITORY_ID' repository."
curl -X DELETE --header "Content-Type: text/plain" "$ADDRESS/namespaces/" $USERNAME_WITH_PASSWORD

# Enable autocomplete index
echo "Enabling autocomplete index for '$REPOSITORY_ID' repository."
curl "$ADDRESS/statements" $USERNAME_WITH_PASSWORD --data-urlencode update='INSERT DATA { _:s <http://www.ontotext.com/plugins/autocomplete#enabled> true . }'

echo "RDF uploaded to $ADDRESS"