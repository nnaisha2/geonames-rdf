#!/bin/sh
set -e
set -x

# Configuration
DATA_DIR="$PWD/data"
BIN_DIR="$PWD/bin"
CONFIG_DIR="$PWD/config"
OUTPUT_DIR="$PWD/output"
SPARQL_ANYTHING_JAR="sparql-anything-v1.0-DEV.15.jar"

# Create directories
mkdir -p "$OUTPUT_DIR" "$BIN_DIR"

# Download SPARQL Anything if needed
if [ ! -f "$BIN_DIR/$SPARQL_ANYTHING_JAR" ]; then
    curl -sSL "https://github.com/SPARQL-Anything/sparql.anything/releases/download/v1.0-DEV.15/$SPARQL_ANYTHING_JAR" \
         -o "$BIN_DIR/$SPARQL_ANYTHING_JAR"
fi

# Process admin codes (all levels)
echo "Processing admin codes..."
java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
    --query "$CONFIG_DIR/admin-codes.rq" \
    --output "$DATA_DIR/admin-codes.ttl"

# Process hierarchy
echo "Processing hierarchy..."
java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
    --query "$CONFIG_DIR/hierarchy.rq" \
    --output "$DATA_DIR/hierarchy.ttl"

# Process places with all dependencies
echo "Processing places..."
for f in "$DATA_DIR"/geonames_*.csv; do
    echo "Processing $f..."
    java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
        --query "$CONFIG_DIR/places.rq" \
        -v "SOURCE=$f" \
        --load "$DATA_DIR/admin-codes.ttl" \
        --load "$DATA_DIR/hierarchy.ttl" \
        --output "$f.ttl"
done

# Process alternate names with all features
echo "Processing alternate names..."
for f in "$DATA_DIR"/alternateNames_*.csv; do
    echo "Processing $f..."
    java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
        --query "$CONFIG_DIR/alternateNames.rq" \
        -v "SOURCE=$f" \
        --load "$DATA_DIR"/geonames_*.csv.ttl \
        --output "$f.ttl"
done

# Final merge with proper ordering
echo "Merging outputs..."
cat "$DATA_DIR"/geonames_*.csv.ttl \
    "$DATA_DIR"/alternateNames_*.csv.ttl \
    "$DATA_DIR"/admin-codes.ttl \
    "$DATA_DIR"/hierarchy.ttl > "$OUTPUT_DIR/geonames-enhanced.ttl"

echo "Processing complete! Enhanced output at:"
echo "  $OUTPUT_DIR/geonames-enhanced.ttl"