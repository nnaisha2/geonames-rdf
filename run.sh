#!/bin/bash
set -e

NO_PROXY=false
POSITIONAL_ARGS=()

# Parse arguments and flags
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

# Set positional arguments
set -- "${POSITIONAL_ARGS[@]}"
COUNTRY_CODE="${1:-DE}"
UPLOAD_TARGET="${2:-qendpoint}"

echo "[1/3] Downloading..."
COUNTRY_CODE=$COUNTRY_CODE docker-compose -f docker-compose.yml up --build geonames-download

echo "[2/3] Transforming..."
COUNTRY_CODE=$COUNTRY_CODE docker-compose -f docker-compose.yml up --build geonames-transform

echo "[3/3] Uploading to $UPLOAD_TARGET..."

# Start geonames-web (always)
docker-compose -f docker-compose.yml up --build -d geonames-web

# Optionally start nginx
if [ "$NO_PROXY" = false ]; then
  echo "Starting nginx proxy..."
  docker-compose --profile proxy -f docker-compose.yml up --build -d nginx
else
  echo "Skipping nginx proxy (--no-proxy flag used)"
fi

# Upload to selected target
if [ "$UPLOAD_TARGET" == "qendpoint" ]; then
  COUNTRY_CODE=$COUNTRY_CODE docker-compose -f docker-compose.yml up --build geonames-upload 
  COUNTRY_CODE=$COUNTRY_CODE docker-compose -f docker-compose.yml up --build -d qendpoint
elif [ "$UPLOAD_TARGET" == "graphdb" ]; then
  COUNTRY_CODE=$COUNTRY_CODE docker-compose -f docker-compose.upload.graphdb.yml up --build
else
  echo "Unknown upload target: $UPLOAD_TARGET"
  exit 1
fi

echo "Pipeline completed successfully."
