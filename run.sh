#!/bin/bash
set -e

NO_PROXY=false
POSITIONAL_ARGS=()

# Parse input arguments and flags
# Collect positional args, detect --no-proxy flag
for arg in "$@"; do
  case $arg in
    --no-proxy)
      NO_PROXY=true
      shift
      ;;
    *)
      POSITIONAL_ARGS+=("$arg")
      ;;
  esac
done

# Reset positional parameters to filtered arguments
set -- "${POSITIONAL_ARGS[@]}"

COUNTRY_CODE="${1:-DE}"
UPLOAD_TARGET="${2:-qendpoint}"
ENDPOINT_URL="${3:-https://geonames.need.energy/sparql}"

# Persist key environment variables in .env for Docker Compose services
echo "COUNTRY_CODE=$COUNTRY_CODE" > .env
echo "UPLOAD_TARGET=$UPLOAD_TARGET" >> .env
echo "ENDPOINT_URL=$ENDPOINT_URL" >> .env

# Step 1: Download GeoNames data
echo "[1/4] Downloading..."
docker compose -f docker-compose.yml up --build geonames-download

# Step 2: Transform data into intermediate RDF formats
echo "[2/4] Transforming..."
docker compose -f docker-compose.yml up --build geonames-transform

# Step 3: Merge RDF files into single dataset
if [ "$UPLOAD_TARGET" == "qendpoint" ]; then
  echo "[3/4] Merging RDF files ..."
  docker compose -f docker-compose.yml up --build geonames-merge
else
  echo "[3/4] Skipping RDF merge ..."
fi

# Step 4: Upload RDF data to target triple store and launch services
echo "[4/4] Uploading to $UPLOAD_TARGET..."

# Always start geonames-web UI
docker compose -f docker-compose.yml up --build -d geonames-web

# Optionally start nginx proxy (skip if --no-proxy flag set)
if [ "$NO_PROXY" = false ]; then
  echo "Starting nginx proxy..."
  docker compose --profile proxy -f docker-compose.yml up --build -d nginx
else
  echo "Skipping nginx proxy (--no-proxy flag used)"
fi

if [ "$UPLOAD_TARGET" == "qendpoint" ]; then
  docker compose -f docker-compose.yml up --build geonames-upload
  docker compose -f docker-compose.yml up --build -d qendpoint
elif [ "$UPLOAD_TARGET" == "graphdb" ]; then
  docker compose -f graphdb/docker-compose.upload.graphdb.yml up --build
else
  echo "Unknown upload target: $UPLOAD_TARGET"
  exit 1
fi

echo "Pipeline completed successfully."