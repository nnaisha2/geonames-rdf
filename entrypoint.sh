#!/bin/bash
set -e # Exit immediately if any command fails

# Configuration
DATA_DIR="$PWD/data"
OUTPUT_DIR="$PWD/output"
BIN_DIR="$PWD/bin"
CONFIG_DIR="$PWD/config"

COUNTRY_CODE="${1:-DE}"  # Accept country code as argument, default to DE
UPLOAD=${UPLOAD:-false}

# Step 1: Download GeoNames data
echo "[1/3] Running download.sh for country code: $COUNTRY_CODE ..."
source ./download.sh "$COUNTRY_CODE"

# Step 2: Transform data to RDF
echo "[2/3] Running map.sh for country code: $COUNTRY_CODE ..."
source ./map.sh "$COUNTRY_CODE"

# Step 3: Upload RDF to GraphDB
if [ "$UPLOAD" = "true" ]; then
    echo "[3/3] Running upload_to_graphdb.sh for country code: $COUNTRY_CODE ..."
    #start_time=$(date +%s)
    source ./upload_to_graphdb.sh "$COUNTRY_CODE"
    #end_time=$(date +%s)
    #duration=$((end_time - start_time))
    #echo "Upload to GraphDB took approximately $duration seconds."
fi

echo "Data preparation complete"
