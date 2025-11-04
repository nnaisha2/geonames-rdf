#!/bin/bash
set -e  # Exit immediately if any command fails

COUNTRY_CODE="${1:-DE}"  # Accept country code as argument, default to DE

# Step 1: Download GeoNames data
echo "[1/3] Running download for country code: $COUNTRY_CODE ..."
source ./entrypoint-download.sh "$COUNTRY_CODE"

# Step 2: Transform data to RDF
echo "[2/3] Running transform for country code: $COUNTRY_CODE ..."
source ./entrypoint-transform.sh "$COUNTRY_CODE"

# Step 3: Upload RDF to GraphDB or qEndpoint
echo "[3/3] Running upload for country code: $COUNTRY_CODE ..."
source ./entrypoint-upload.sh "$COUNTRY_CODE"

echo "Data preparation complete."
