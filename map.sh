#!/bin/sh
set -e # Exit immediately if any command fails
#set -x  

COUNTRY_CODE="${1:-DE}"

# Configuration
DATA_DIR="$PWD/data"
BIN_DIR="$PWD/bin"
CONFIG_DIR="$PWD/config"
OUTPUT_DIR="$PWD/output"
SPARQL_ANYTHING_JAR="sparql-anything-v1.0.0.jar"

# Create directories
echo "[transform 1/7] Creating output and bin directories for $COUNTRY_CODE..."
mkdir -p "$OUTPUT_DIR" "$BIN_DIR"

# Download SPARQL Anything if needed
echo "[transform 2/7] Checking for SPARQL Anything JAR..."
if [ ! -f "$BIN_DIR/$SPARQL_ANYTHING_JAR" ]; then
    echo "  - Downloading SPARQL Anything..."
    curl -sSL "https://github.com/SPARQL-Anything/sparql.anything/releases/download/v1.0.0/${SPARQL_ANYTHING_JAR}" \
      -o "$BIN_DIR/${SPARQL_ANYTHING_JAR}"
fi

# Process admin codes (all levels)
echo "[transform 3/7] Processing admin codes for $COUNTRY_CODE..."
java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
    --query "$CONFIG_DIR/admin-codes.rq" \
    --output "$DATA_DIR/admin-codes.ttl"


# Process places with all dependencies
echo "[transform 4/7] Processing places for $COUNTRY_CODE..."
for f in "$DATA_DIR"/geonames_${COUNTRY_CODE}_*.csv; do
    echo "  - Processing $f..."
    java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
        --query "$CONFIG_DIR/places.rq" \
        -v "SOURCE=$f" \
        --load "$DATA_DIR/admin-codes.ttl" \
        --output "$f.ttl"
done

# Process alternate names with all features
echo "[transform 5/7] Processing alternate names for $COUNTRY_CODE..."
for f in "$DATA_DIR"/alternateNamesV2_${COUNTRY_CODE}_*.csv; do
    echo "  - Processing $f..."
    java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
        --query "$CONFIG_DIR/alternateNames.rq" \
        -v "SOURCE=$f" \
        --load "$DATA_DIR"/geonames_${COUNTRY_CODE}_*.csv.ttl \
        --output "$f.ttl"
done

# Final merge with proper ordering
echo "[transform 6/7] Merging outputs for $COUNTRY_CODE..."
cat "$DATA_DIR"/geonames_${COUNTRY_CODE}_*.csv.ttl \
    "$DATA_DIR"/alternateNamesV2_${COUNTRY_CODE}_*.csv.ttl \
    "$DATA_DIR"/admin-codes.ttl > "$OUTPUT_DIR/geonames_${COUNTRY_CODE}_pre_optimization.ttl"

# Optimize output format
echo "[transform 7/7] Optimizing output format for $COUNTRY_CODE..."
java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
    --query "$CONFIG_DIR/consolidate.rq" \
    --load "$OUTPUT_DIR/geonames_${COUNTRY_CODE}_pre_optimization.ttl" \
    --output "$OUTPUT_DIR/geonames_${COUNTRY_CODE}.ttl"

echo "Final output at:"
echo "  $OUTPUT_DIR/geonames_${COUNTRY_CODE}.ttl"