#!/bin/bash

set -e
COUNTRY_CODE="${1:-DE}"

OUTPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../output" && pwd)"
ONTOLOGY="$OUTPUT_DIR/ontology_v3.3_modified.rdf"       # Ontology RDF file in RDF/XML format
DATA="$OUTPUT_DIR/geonames_${COUNTRY_CODE}.ttl"         # Geonames data file in Turtle format for the given country
MERGED="$OUTPUT_DIR/geonames_${COUNTRY_CODE}_merged.ttl" # Output merged Turtle file

# Convert the ontology RDF/XML file to N-Triples format and save as ontology.nt
rapper -i rdfxml -o ntriples "$ONTOLOGY" > "$OUTPUT_DIR/ontology.nt"

# Convert the geonames Turtle file to N-Triples format and save as data.nt
rapper -i turtle -o ntriples "$DATA" > "$OUTPUT_DIR/data.nt"

# Concatenate the two N-Triples files into one merged N-Triples file
cat "$OUTPUT_DIR/ontology.nt" "$OUTPUT_DIR/data.nt" > "$OUTPUT_DIR/merged.nt"

# Convert the merged N-Triples file back to Turtle format for easier readability/use
rapper -i ntriples -o turtle "$OUTPUT_DIR/merged.nt" > "$MERGED"

# Clean up intermediate N-Triples files used in the merging process
rm "$OUTPUT_DIR/ontology.nt" "$OUTPUT_DIR/data.nt" "$OUTPUT_DIR/merged.nt"

# Print a confirmation message with the location of the merged output file
echo "Merged file created: $MERGED"
