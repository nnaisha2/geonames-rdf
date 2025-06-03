#!/bin/sh
DATA_DIR="$PWD/data"
BIN_DIR="$PWD/bin"
CONFIG_DIR="$PWD/config"
OUTPUT_DIR="$PWD/output"
: "${SPARQL_ANYTHING_VERSION:=v1.0-DEV.15}"
: "${JENA_GEOSPARQL_VERSION:=4.0.0}"
: "${JENA_CORE_VERSION:=4.0.0}"
: "${JENA_ARQ_VERSION:=4.0.0}"

# JAR filenames
SPARQL_ANYTHING_JAR="sparql-anything-$SPARQL_ANYTHING_VERSION.jar"
JENA_GEOSPARQL_JAR="jena-geosparql-$JENA_GEOSPARQL_VERSION.jar"
JENA_CORE_JAR="jena-core-$JENA_CORE_VERSION.jar"
JENA_ARQ_JAR="jena-arq-$JENA_ARQ_VERSION.jar"


mkdir -p $OUTPUT_DIR

# Dependency download base URL
JENA_BASE="https://repo1.maven.org/maven2/org/apache/jena"

# Download required components
[ ! -f "$BIN_DIR/$SPARQL_ANYTHING_JAR" ] && curl -sSL \
  "https://github.com/SPARQL-Anything/sparql.anything/releases/download/$SPARQL_ANYTHING_VERSION/$SPARQL_ANYTHING_JAR" \
  -o "$BIN_DIR/$SPARQL_ANYTHING_JAR"

[ ! -f "$BIN_DIR/$JENA_GEOSPARQL_JAR" ] && curl -sSL \
  "$JENA_BASE/jena-geosparql/$JENA_GEOSPARQL_VERSION/$JENA_GEOSPARQL_JAR" \
  -o "$BIN_DIR/$JENA_GEOSPARQL_JAR"

[ ! -f "$BIN_DIR/$JENA_CORE_JAR" ] && curl -sSL \
  "$JENA_BASE/jena-core/$JENA_CORE_VERSION/$JENA_CORE_JAR" \
  -o "$BIN_DIR/$JENA_CORE_JAR"

[ ! -f "$BIN_DIR/$JENA_ARQ_JAR" ] && curl -sSL \
  "$JENA_BASE/jena-arq/$JENA_ARQ_VERSION/$JENA_ARQ_JAR" \
  -o "$BIN_DIR/$JENA_ARQ_JAR"

# Classpath configuration
CLASSPATH="$BIN_DIR/$SPARQL_ANYTHING_JAR:\
$BIN_DIR/$JENA_GEOSPARQL_JAR:\
$BIN_DIR/$JENA_CORE_JAR:\
$BIN_DIR/$JENA_ARQ_JAR"

# Process admin codes
java -cp $CLASSPATH io.github.sparqlanything.cli.SPARQLAnything \
  -q "$CONFIG_DIR/admin-codes.rq" > "$DATA_DIR/admin-codes.ttl"

# Process geonames chunks
trap "exit 1" INT
for f in "$DATA_DIR"/geonames_*.csv; do
  echo "Processing $f"
  java -cp $CLASSPATH io.github.sparqlanything.cli.SPARQLAnything \
    --query "$(sed "s|{SOURCE}|$f|" "$CONFIG_DIR/places.rq")" \
    --load "$DATA_DIR/admin-codes.ttl" \
    --output "$f.ttl"
done

# Process alternateNames
for f in "$DATA_DIR"/alternateNamesV2_*.csv; do
  echo "Processing $f"
  java -cp $CLASSPATH io.github.sparqlanything.cli.SPARQLAnything \
    --query "$CONFIG_DIR/alternateNames.rq" \
    --output "$f.ttl" \
    -v "SOURCE=$f"
done

# Process hierarchy
java -cp $CLASSPATH io.github.sparqlanything.cli.SPARQLAnything \
  --query "$CONFIG_DIR/hierarchy.rq" \
  --output "$DATA_DIR/hierarchy.ttl"

# Merge outputs
shopt -s nullglob
cat "$DATA_DIR"/geonames_*.csv.ttl \
    "$DATA_DIR"/admin-codes.ttl \
    "$DATA_DIR"/alternateNamesV2_*.csv.ttl \
    "$DATA_DIR"/hierarchy.ttl > "$OUTPUT_DIR/geonames.ttl"

# Cleanup

rm -f "$DATA_DIR"/geonames_*.csv "$DATA_DIR"/geonames_*.csv.ttl \
      "$DATA_DIR"/alternateNamesV2_*.csv "$DATA_DIR"/alternateNamesV2_*.csv.ttl \
      "$DATA_DIR"/hierarchy.ttl "$DATA_DIR"/admin-codes.ttl

echo "Processing complete. Final output: $OUTPUT_DIR/geonames.ttl"