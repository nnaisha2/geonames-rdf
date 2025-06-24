#!/bin/bash
set -e # Exit immediately if any command fails

DATA_DIR="$PWD/data"
OUTPUT_DIR="$PWD/output"
BIN_DIR="$PWD/bin"
CONFIG_DIR="$PWD/config"

# Step 1: Download GeoNames data
echo "[1/2] Running download.sh..."
source ./download.sh

# Step 2: Transform data to RDF
echo "[2/2] Running map.sh..."
source ./map.sh

echo "Data preparation complete. RDF file should be at $OUTPUT_DIR/geonames.ttl"
