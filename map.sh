
#!/bin/sh
set -e  # Exit immediately if any command fails
set -x  # Print commands as they execute (for debugging)

# This script processes Geonames data into RDF (Turtle format) using SPARQL Anything.
# It handles:
# 1. Downloading required Java dependencies
# 2. Processing administrative codes
# 3. Converting Geonames places to RDF
# 4. Handling alternate names
# 5. Processing hierarchy data
# 6. Merging all outputs into a single TTL file

# ---------------------------
# Configuration Section
# ---------------------------
echo "Initializing configuration..."

# Directory setup
DATA_DIR="$PWD/data"      # Contains input Geonames CSV files
BIN_DIR="$PWD/bin"        # Stores downloaded JAR dependencies
CONFIG_DIR="$PWD/config"  # SPARQL query templates
OUTPUT_DIR="$PWD/output"  # Final output location

# Version configuration (with defaults)
: "${SPARQL_ANYTHING_VERSION:=v1.0-DEV.15}"  # SPARQL Anything toolkit
: "${JENA_GEOSPARQL_VERSION:=4.0.0}"         # GeoSPARQL support
: "${JENA_CORE_VERSION:=4.0.0}"              # Apache Jena core
: "${JENA_ARQ_VERSION:=4.0.0}"               # Jena ARQ query engine

# Derived JAR filenames
SPARQL_ANYTHING_JAR="sparql-anything-$SPARQL_ANYTHING_VERSION.jar"
JENA_GEOSPARQL_JAR="jena-geosparql-$JENA_GEOSPARQL_VERSION.jar"
JENA_CORE_JAR="jena-core-$JENA_CORE_VERSION.jar"
JENA_ARQ_JAR="jena-arq-$JENA_ARQ_VERSION.jar"

echo "Creating output directories..."
mkdir -p "$OUTPUT_DIR" "$BIN_DIR"


# Dependency Download

echo "Checking for required dependencies..."

JENA_BASE="https://repo1.maven.org/maven2/org/apache/jena"

# Download SPARQL Anything (if missing)
if [ ! -f "$BIN_DIR/$SPARQL_ANYTHING_JAR" ]; then
    echo "Downloading SPARQL Anything ($SPARQL_ANYTHING_VERSION)..."
    curl -sSL \
      "https://github.com/SPARQL-Anything/sparql.anything/releases/download/$SPARQL_ANYTHING_VERSION/$SPARQL_ANYTHING_JAR" \
      -o "$BIN_DIR/$SPARQL_ANYTHING_JAR"
fi

# Download Jena GeoSPARQL (if missing)
if [ ! -f "$BIN_DIR/$JENA_GEOSPARQL_JAR" ]; then
    echo "Downloading Jena GeoSPARQL ($JENA_GEOSPARQL_VERSION)..."
    curl -sSL \
      "$JENA_BASE/jena-geosparql/$JENA_GEOSPARQL_VERSION/$JENA_GEOSPARQL_JAR" \
      -o "$BIN_DIR/$JENA_GEOSPARQL_JAR"
fi

# Download Jena Core (if missing)
if [ ! -f "$BIN_DIR/$JENA_CORE_JAR" ]; then
    echo "Downloading Jena Core ($JENA_CORE_VERSION)..."
    curl -sSL \
      "$JENA_BASE/jena-core/$JENA_CORE_VERSION/$JENA_CORE_JAR" \
      -o "$BIN_DIR/$JENA_CORE_JAR"
fi

# Download Jena ARQ (if missing)
if [ ! -f "$BIN_DIR/$JENA_ARQ_JAR" ]; then
    echo "Downloading Jena ARQ ($JENA_ARQ_VERSION)..."
    curl -sSL \
      "$JENA_BASE/jena-arq/$JENA_ARQ_VERSION/$JENA_ARQ_JAR" \
      -o "$BIN_DIR/$JENA_ARQ_JAR"
fi

# Build classpath
CLASSPATH="$BIN_DIR/$SPARQL_ANYTHING_JAR:$BIN_DIR/$JENA_GEOSPARQL_JAR:$BIN_DIR/$JENA_CORE_JAR:$BIN_DIR/$JENA_ARQ_JAR"
echo "Classpath configured: $CLASSPATH"


# Data Processing Pipeline


# --- 1. Generate admin codes mapping ---

# Creates RDF representations of administrative hierarchies (ADM1, ADM2, etc.)
echo "Processing administrative codes..."
java -cp "$CLASSPATH" io.github.sparqlanything.cli.SPARQLAnything \
  --query "$CONFIG_DIR/admin-codes.rq" \
  --output "$DATA_DIR/admin-codes.ttl"

# --- 2. Process Geonames place chunks ---

# Converts each CSV chunk to RDF using places.rq template
echo "Processing Geonames place chunks..."
for f in "$DATA_DIR"/geonames_*.csv; do
  relf="data/$(basename "$f")"  # Relative path for SPARQL Anything
  echo "  Processing $relf..."
  java -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" \
    --query "$CONFIG_DIR/places.rq" \
    --output "$f.ttl" \
    -v "SOURCE=$relf" \
    #--load "$DATA_DIR/admin-codes.ttl" \
    #--load "$DATA_DIR/hierarchy.ttl" \
    #--load "$DATA_DIR/alternateNames.ttl" \
  2>> "$OUTPUT_DIR/error.log" || { echo "Error processing $f"; exit 1; }
done

# --- 3. Process alternate names chunks ---

# Handles multilingual name variants for German locations
echo "Processing alternate names..."
for f in "$DATA_DIR"/alternateNamesV2_DE_*.csv; do
  echo "  Converting $f to RDF..."
  java -cp "$CLASSPATH" io.github.sparqlanything.cli.SPARQLAnything \
    --query "$CONFIG_DIR/alternateNames.rq" \
    --output "$f.ttl" \
    -v "SOURCE=$f"
done

# --- 4. Process hierarchy ---

# Converts parent-child relationships between places
echo "Processing hierarchies..."
java -cp "$CLASSPATH" io.github.sparqlanything.cli.SPARQLAnything \
  --query "$CONFIG_DIR/hierarchy.rq" \
  --output "$DATA_DIR/hierarchy.ttl"

# --- 5. Merge all TTL outputs ---

# Combines all RDF fragments into a single knowledge graph
echo "Merging all RDF outputs..."
cat "$DATA_DIR"/geonames_*.csv.ttl \
    "$DATA_DIR"/admin-codes.ttl \
    "$DATA_DIR"/alternateNamesV2_DE_*.csv.ttl \
    "$DATA_DIR"/hierarchy.ttl > "$OUTPUT_DIR/geonames.ttl"

# --- 6. Cleanup ---
#echo "Cleaning up temporary files..."
#rm -f "$DATA_DIR"/geonames_*.csv "$DATA_DIR"/geonames_*.csv.ttl \
      #"$DATA_DIR"/alternateNamesV2_DE_*.csv "$DATA_DIR"/alternateNamesV2_DE_*.csv.ttl \
      #"$DATA_DIR"/hierarchy.ttl "$DATA_DIR"/admin-codes.ttl

echo "Processing complete! Final output available at:"
echo "  $OUTPUT_DIR/geonames.ttl"