#!/bin/bash

set -e
COUNTRY_CODE="${1:-DE}"

OUTPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../output" && pwd)"
ONTOLOGY="$OUTPUT_DIR/ontology_v3.3_modified.rdf"       # Ontology RDF file in RDF/XML format
DATA="$OUTPUT_DIR/geonames_${COUNTRY_CODE}.ttl"         # Geonames data file in Turtle format
MERGED="$OUTPUT_DIR/geonames_${COUNTRY_CODE}_merged.ttl" # Output merged Turtle file

# Convert RDF/XML ontology to Turtle
rapper -i rdfxml -o turtle "$ONTOLOGY" > "$OUTPUT_DIR/ontology.ttl"

# Concatenate ontology and data
cat "$OUTPUT_DIR/ontology.ttl" "$DATA" > "$OUTPUT_DIR/merged_raw.ttl"

# Normalize the merged file with rapper
rapper -i turtle -o turtle "$OUTPUT_DIR/merged_raw.ttl" > "$MERGED"

# Clean up temporary files
rm "$OUTPUT_DIR/ontology.ttl" "$OUTPUT_DIR/merged_raw.ttl"

echo "Merged file created: $MERGED"
