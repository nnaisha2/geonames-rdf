#!/bin/bash
set -e

DATA_DIR="$PWD/data"
OUTPUT_DIR="$PWD/output"
BIN_DIR="$PWD/bin"
CONFIG_DIR="$PWD/config"
REPOSITORY_ID="geonames"
ADDRESS="http://localhost:7200/repositories/$REPOSITORY_ID"
USERNAME_WITH_PASSWORD=""  # Optional: -u user:pass
REPOSITORY_CONFIG="$CONFIG_DIR/repository.ttl"

#Downloads DE.txt, alternateNamesV2.txt, hierarchy.txt, etc.
echo "[1/6] Running download.sh..."
source ./download.sh

#Transforms geonames_*.csv → *.csv.ttl, alternateNamesV2.txt → alternate-names.ttl, hierarchy.txt → hierarchy.ttl and Combines into output/geonames.ttl
echo "[2/6] Running map.sh..."
source ./map.sh

#deletes the existing GraphDB repository (if it exists)
echo "[3/6] Removing '$REPOSITORY_ID' repository."
curl -X DELETE "$ADDRESS" $USERNAME_WITH_PASSWORD || true


echo "[4/6] Creating '$REPOSITORY_ID' repository."
curl -X PUT --header "Content-Type: application/x-turtle" \
  --data-binary @$REPOSITORY_CONFIG \
  "$ADDRESS" $USERNAME_WITH_PASSWORD

echo "Uploading all ontology files into contexts."
curl -X POST --header "Content-Type: application/x-turtle" --data-binary @${ontologyfile} $ADDRESS/rdf-graphs/service $USERNAME_WITH_PASSWORD --url-query "graph=$ontology_iri"
 

#loops through all .ttl files in output and Uploads each to the GraphDB store 
echo "[5/6] Uploading RDF to GraphDB..."
for ttlfile in $OUTPUT_DIR/*.ttl; do
  echo "Uploading $ttlfile"
  curl -X POST --header "Content-Type: application/x-turtle" \
    --data-binary @$ttlfile \
    "$ADDRESS/statements" $USERNAME_WITH_PASSWORD
  ech
done

#Disables and re-enables the GeoSPARQL plugin
echo "[6/6] Refreshing GeoSPARQL plugin..."
curl "$ADDRESS/statements" $USERNAME_WITH_PASSWORD --data-urlencode update='INSERT DATA { [] <http://www.ontotext.com/plugins/geosparql#enabled> "false" . } ; INSERT DATA { [] <http://www.ontotext.com/plugins/geosparql#enabled> "true" . }'

echo "Deleting empty namespace prefix in '$REPOSITORY_ID' repository."
curl -X DELETE --header "Content-Type: text/plain" "$ADDRESS/namespaces/" $USERNAME_WITH_PASSWORD


echo "Enabling autocomplete index for '$REPOSITORY_ID' repository."
curl "$ADDRESS/statements" $USERNAME_WITH_PASSWORD --data-urlencode update='INSERT DATA { _:s <http://www.ontotext.com/plugins/autocomplete#enabled> true . }'

echo " RDF uploaded to $ADDRESS"
