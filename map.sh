#!/bin/sh
set -e
set -x  

COUNTRY_CODE="${1:-DE}"

# Configuration
DATA_DIR="$PWD/data"
BIN_DIR="$PWD/bin"
CONFIG_DIR="$PWD/config"
OUTPUT_DIR="$PWD/output"
SPARQL_ANYTHING_JAR="sparql-anything-v1.0.0.jar"

# Create directories
echo "[transform 1/8] Creating output and bin directories for $COUNTRY_CODE..."
mkdir -p "$OUTPUT_DIR" "$BIN_DIR"

# Download SPARQL Anything if needed
echo "[transform 2/8] Checking for SPARQL Anything JAR..."
if [ ! -f "$BIN_DIR/$SPARQL_ANYTHING_JAR" ]; then
    echo "  - Downloading SPARQL Anything..."
    curl -sSL "https://github.com/SPARQL-Anything/sparql.anything/releases/download/v1.0.0/${SPARQL_ANYTHING_JAR}" \
      -o "$BIN_DIR/${SPARQL_ANYTHING_JAR}"
fi

# Download the Geonames ontology
echo "[transform 3/8] Downloading Geonames ontology..."
if [ ! -f "$OUTPUT_DIR/ontology_v3.3.rdf" ]; then
    curl -sSfL "https://download.geonames.org/ontology/ontology_v3.3.rdf" -o "$OUTPUT_DIR/ontology_v3.3.rdf"
    echo "  - ontology_v3.3.rdf downloaded."
else
    echo "  - ontology_v3.3.rdf already present."
fi

# Process admin codes (all levels)
echo "[transform 4/8] Processing admin codes for $COUNTRY_CODE..."
java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
    --query "$CONFIG_DIR/admin-codes.rq" \
    --output "$DATA_DIR/admin-codes.ttl"

# Process AGS lookup file to produce ags-lookup.ttl
echo "[transform 5/8] Processing AGS lookup for $COUNTRY_CODE..."
if [ "$COUNTRY_CODE" = "DE" ]; then
    java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
        --query "$CONFIG_DIR/ags-lookup.rq" \
        --output "$DATA_DIR/ags-lookup.ttl"
else
    echo "Skipping AGS lookup step because country code is not DE"
    # Create empty placeholder so subsequent steps do not fail
    touch "$DATA_DIR/ags-lookup.ttl"
fi

# Process places with all dependencies
echo "[transform 6/8] Processing places for $COUNTRY_CODE..."
for f in "$DATA_DIR"/geonames_${COUNTRY_CODE}_*.csv; do
    echo "  - Processing $f..."
    java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
        --query "$CONFIG_DIR/places.rq" \
        -v "SOURCE=$f" \
        --load "$DATA_DIR/admin-codes.ttl" \
        --output "$f.ttl"
done

# Process alternate names with all features
echo "[transform 7/8] Processing alternate names for $COUNTRY_CODE..."
for f in "$DATA_DIR"/alternateNamesV2_${COUNTRY_CODE}_*.csv; do
    echo "  - Processing $f..."
    java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
        --query "$CONFIG_DIR/alternateNames.rq" \
        -v "SOURCE=$f" \
        --load "$DATA_DIR"/geonames_${COUNTRY_CODE}_*.csv.ttl \
        --output "$f.ttl"
done

# Final merge with proper ordering
echo "[transform 8/8] Merging outputs for $COUNTRY_CODE..."
if [ "$COUNTRY_CODE" = "DE" ]; then
    cat "$DATA_DIR"/geonames_${COUNTRY_CODE}_*.csv.ttl \
        "$DATA_DIR"/ags-lookup.ttl \
        "$CONFIG_DIR"/property-definitions.ttl \
        "$DATA_DIR"/alternateNamesV2_${COUNTRY_CODE}_*.csv.ttl > "$OUTPUT_DIR"/geonames_${COUNTRY_CODE}_pre_optimization.ttl
else
    cat "$DATA_DIR"/geonames_${COUNTRY_CODE}_*.csv.ttl \
        "$DATA_DIR"/ags-lookup.ttl \
        "$DATA_DIR"/alternateNamesV2_${COUNTRY_CODE}_*.csv.ttl > "$OUTPUT_DIR"/geonames_${COUNTRY_CODE}_pre_optimization.ttl
fi

# Optimize output format
echo "Optimizing output format for $COUNTRY_CODE..."
java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
    --query "$CONFIG_DIR/consolidate.rq" \
    --load "$OUTPUT_DIR/geonames_${COUNTRY_CODE}_pre_optimization.ttl" \
    --output "$OUTPUT_DIR/geonames_${COUNTRY_CODE}.ttl"

echo "Final output at:"
echo "  $OUTPUT_DIR/geonames_${COUNTRY_CODE}.ttl"