#!/bin/sh
set -e # Exit immediately if any command fails
#set -x  

# Configuration
DATA_DIR="$PWD/data"
BIN_DIR="$PWD/bin"
CONFIG_DIR="$PWD/config"
OUTPUT_DIR="$PWD/output"
SPARQL_ANYTHING_JAR="sparql-anything-v1.0-DEV.15.jar"

# Create directories
echo "[transform 1/9] Creating output and bin directories..."
mkdir -p "$OUTPUT_DIR" "$BIN_DIR"

# Download SPARQL Anything if needed
echo "[transform 2/9] Checking for SPARQL Anything JAR..."
if [ ! -f "$BIN_DIR/$SPARQL_ANYTHING_JAR" ]; then
    echo "  - Downloading SPARQL Anything..."
    curl -sSL "https://github.com/SPARQL-Anything/sparql.anything/releases/download/v1.0-DEV.15/$SPARQL_ANYTHING_JAR" \
         -o "$BIN_DIR/$SPARQL_ANYTHING_JAR"
fi

# Process admin codes (all levels)
echo "[transform 3/9] Processing admin codes..."
java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
    --query "$CONFIG_DIR/admin-codes.rq" \
    --output "$DATA_DIR/admin-codes.ttl"

# Process hierarchy
echo "[transform 4/9] Processing hierarchy..."
java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
    --query "$CONFIG_DIR/hierarchy.rq" \
    --output "$DATA_DIR/hierarchy.ttl"

# Process places with all dependencies
echo "[transform 5/9] Processing places..."
for f in "$DATA_DIR"/geonames_*.csv; do
    echo "  - Processing $f..."
    java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
        --query "$CONFIG_DIR/places.rq" \
        -v "SOURCE=$f" \
        --load "$DATA_DIR/admin-codes.ttl" \
        --load "$DATA_DIR/hierarchy.ttl" \
        --output "$f.ttl"
done

# Process alternate names with all features
echo "[transform 6/9] Processing alternate names..."
for f in "$DATA_DIR"/alternateNamesV2_DE_*.csv; do
    echo "  - Processing $f..."
    java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
        --query "$CONFIG_DIR/alternateNames.rq" \
        -v "SOURCE=$f" \
        --load "$DATA_DIR"/geonames_*.csv.ttl \
        --output "$f.ttl"
done

#process postal codes
echo "[transform 7/9] Processing postal codes..."
java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
    --query "$CONFIG_DIR/postal-codes.rq" \
    --load "$DATA_DIR/admin-codes.ttl" \
    --output "$DATA_DIR/postal-codes.ttl"


# Final merge with proper ordering
echo "[transform 8/9] Merging outputs..."
cat "$DATA_DIR"/geonames_*.csv.ttl \
    "$DATA_DIR"/alternateNamesV2_*.csv.ttl \
    "$DATA_DIR"/admin-codes.ttl \
    "$DATA_DIR"/hierarchy.ttl \
    "$DATA_DIR"/postal-codes.ttl > "$OUTPUT_DIR/geonames_pre_optimization.ttl"

# Optimize output format
echo "[transform 9/9] Optimizing output format..."
java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
    --query "$CONFIG_DIR/consolidate.rq" \
    --load "$OUTPUT_DIR/geonames_pre_optimization.ttl" \
    --output "$OUTPUT_DIR/geonames.ttl"


echo "Final output at:"
echo "  $OUTPUT_DIR/geonames.ttl"