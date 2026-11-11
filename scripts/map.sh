#!/bin/bash

set -e

# --- Configuration ---
COUNTRY_CODE="${1:-DE}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
DATA_DIR="$ROOT_DIR/data"
BIN_DIR="$ROOT_DIR/bin"
CONFIG_DIR="$ROOT_DIR/config"
OUTPUT_DIR="$ROOT_DIR/output"
SPARQL_ANYTHING_VERSION="${SPARQL_ANYTHING_VERSION:-v1.3.0}"
SPARQL_ANYTHING_JAR="sparql-anything-$SPARQL_ANYTHING_VERSION.jar"
# SHA-256 of the v1.3.0 jar; keep in sync with the Dockerfile
SPARQL_ANYTHING_SHA256="${SPARQL_ANYTHING_SHA256:-0855bc869a35f83c4a97a5d31ca65e9f4ff16fd9c5a4f619ad7a7bd508053414}"
CURRENT_DATE=$(date +%F)


# Step 1: Create directories
echo "[transform 1/8] Creating output and bin directories for $COUNTRY_CODE..."
mkdir -p "$OUTPUT_DIR" "$BIN_DIR"

# Step 2: Download SPARQL Anything if missing
echo "[transform 2/8] Checking for SPARQL Anything JAR..."
if [ ! -f "$BIN_DIR/$SPARQL_ANYTHING_JAR" ]; then
    echo "  - Downloading SPARQL Anything..."
    curl -sSfL "https://github.com/SPARQL-Anything/sparql.anything/releases/download/${SPARQL_ANYTHING_VERSION}/${SPARQL_ANYTHING_JAR}" \
      -o "$BIN_DIR/${SPARQL_ANYTHING_JAR}.part"
    # Verify the checksum before using the jar (sha256sum on Linux, shasum on macOS)
    if command -v sha256sum >/dev/null; then
        actual_sha=$(sha256sum "$BIN_DIR/${SPARQL_ANYTHING_JAR}.part" | cut -d' ' -f1)
    else
        actual_sha=$(shasum -a 256 "$BIN_DIR/${SPARQL_ANYTHING_JAR}.part" | cut -d' ' -f1)
    fi
    if [ "$actual_sha" != "$SPARQL_ANYTHING_SHA256" ]; then
        rm -f "$BIN_DIR/${SPARQL_ANYTHING_JAR}.part"
        echo "Error: checksum mismatch for $SPARQL_ANYTHING_JAR (expected $SPARQL_ANYTHING_SHA256, got $actual_sha)"
        exit 1
    fi
    mv "$BIN_DIR/${SPARQL_ANYTHING_JAR}.part" "$BIN_DIR/${SPARQL_ANYTHING_JAR}"
fi

# Step 3: Geonames ontology
echo "[transform 3/8] Skip Downloading Geonames ontology..."
#if [ ! -f "$OUTPUT_DIR/ontology_v3.3.rdf" ]; then
   # curl -sSfL "https://www.geonames.org/ontology/ontology_v3.3.rdf" -o "$OUTPUT_DIR/ontology_v3.3.rdf"
    #echo "  - ontology_v3.3.rdf downloaded."
#else
    #echo "  - ontology_v3.3.rdf already present."
#fi


# Step 4: Generate admin codes TTL
echo "[transform 4/8] Processing admin codes for $COUNTRY_CODE..."
java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
    --query "$CONFIG_DIR/admin-codes.rq" \
    --output "$DATA_DIR/admin-codes.ttl"

# Step 5: Generate AGS lookup TTL (DE only)
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

# Step 6: Generate place TTLs
echo "[transform 6/8] Processing places for $COUNTRY_CODE..."
for f in "$DATA_DIR"/geonames_${COUNTRY_CODE}_*.csv; do
    echo "  - Processing $f..."
    java -Xmx4g -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
        --query "$CONFIG_DIR/places.rq" \
        -v "SOURCE=$f" \
        --load "$DATA_DIR/admin-codes.ttl" \
        --output "$f.ttl"
done

# Step 7: Generate alternate names TTLs
echo "[transform 7/8] Processing alternate names for $COUNTRY_CODE..."
for f in "$DATA_DIR"/alternateNamesV2_${COUNTRY_CODE}_*.csv; do
    echo "  - Processing $f..."
    java -Xmx4g -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
        --query "$CONFIG_DIR/alternateNames.rq" \
        -v "SOURCE=$f" \
        --load "$DATA_DIR"/geonames_${COUNTRY_CODE}_*.csv.ttl \
        --output "$f.ttl"
done

# Step 8: Merge, consolidate, and version outputs
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

echo "Optimizing output format for $COUNTRY_CODE..."
java -Xmx4g -jar  "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
    --query "$CONFIG_DIR/consolidate.rq" \
    --load "$OUTPUT_DIR/geonames_${COUNTRY_CODE}_pre_optimization.ttl" \
    --output "$OUTPUT_DIR/geonames_${COUNTRY_CODE}.ttl"

# Cleanup and versioning
find "$OUTPUT_DIR" -maxdepth 1 -type f \( -name "geonames_${COUNTRY_CODE}_*.ttl" -o -name "geonames_${COUNTRY_CODE}_*.ttl.zip" \) \
  ! -name "geonames_${COUNTRY_CODE}_${CURRENT_DATE}.ttl" \
  ! -name "geonames_${COUNTRY_CODE}_${CURRENT_DATE}.ttl.zip" \
  -exec rm -f {} +

# Version today's output
ttl_file="$OUTPUT_DIR/geonames_${COUNTRY_CODE}.ttl"
if [ -f "$ttl_file" ]; then
  versioned_ttl="geonames_${COUNTRY_CODE}_${CURRENT_DATE}.ttl"
  cp "$ttl_file" "$OUTPUT_DIR/$versioned_ttl"
  zip -j "$OUTPUT_DIR/${versioned_ttl}.zip" "$OUTPUT_DIR/$versioned_ttl"
  
  # Update web index with date, endpoint, and version
  cp "$ROOT_DIR/web/index.template.html" "$ROOT_DIR/web/index.html"
  sed -i.bak "s/\[DATE\]/$CURRENT_DATE/g" "$ROOT_DIR/web/index.html" && rm -f "$ROOT_DIR/web/index.html.bak"
  sed -i.bak "s|\[ENDPOINT_BASE_URL\]|$ENDPOINT_BASE_URL|g" "$ROOT_DIR/web/index.html" && rm -f "$ROOT_DIR/web/index.html.bak"
  sed -i.bak "s|\[VERSIONED_FILE\]|${versioned_ttl}.zip|g" "$ROOT_DIR/web/index.html" && rm -f "$ROOT_DIR/web/index.html.bak"
  
   # Refresh countryInfo to map country code to country name
  curl -sSfR --connect-timeout 30 --max-time 120 -z "$DATA_DIR/downloads/countryInfo.txt" -o "$DATA_DIR/downloads/countryInfo.txt" "https://download.geonames.org/export/dump/countryInfo.txt" || true

  if [ "$COUNTRY_CODE" = "allCountries" ]; then
    COUNTRY_NAME="All Countries"
  else
    COUNTRY_NAME=$(awk -F'\t' -v code="$COUNTRY_CODE" '$1 == code {print $5}' "$DATA_DIR/downloads/countryInfo.txt")
    COUNTRY_NAME="${COUNTRY_NAME:-$COUNTRY_CODE}"
  fi

  sed -i.bak "s/\[COUNTRY_NAME\]/$COUNTRY_NAME/g" "$ROOT_DIR/web/index.html" && rm -f "$ROOT_DIR/web/index.html.bak"

  echo "Updated index.html for $COUNTRY_CODE with country name '$COUNTRY_NAME' on $CURRENT_DATE"
else
  echo "No TTL file found at $ttl_file"
  exit 1
fi
echo "Final output at:"
echo "  $OUTPUT_DIR/geonames_${COUNTRY_CODE}.ttl"
