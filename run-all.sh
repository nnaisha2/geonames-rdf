#!/bin/bash
set -e
COUNTRY_CODE="${1:-DE}"
UPLOAD_TARGET="${2:-qendpoint}"

echo "[1/4] Downloading..."
COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.download.yml up --build

echo "[2/4] Transforming..."
COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.transform.yml up --build

# Create latest.json for the frontend
latest_ttl=$(basename $(ls output/geonames_*.ttl | grep -v "_pre_optimization" | head -n 1) 2>/dev/null || true)
if [ -n "$latest_ttl" ] && [ -f "output/$latest_ttl" ]; then
  echo "{\"latestFile\": \"$latest_ttl\"}" > web/latest.json
  echo " Created web/latest.json -> $latest_ttl"
else
  echo "No final TTL file found in output/"
fi

echo "[3/4] Uploading to $UPLOAD_TARGET..."
if [ "$UPLOAD_TARGET" == "qendpoint" ]; then
  COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.upload.yml up --build
elif [ "$UPLOAD_TARGET" == "graphdb" ]; then
  COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.upload.graphdb.yml up --build
else
  echo "Unknown upload target: $UPLOAD_TARGET"
  exit 1
fi

echo "[4/4] Starting Web Server..."
docker compose -f docker-compose.web.yml up --build -d

echo "Pipeline completed successfully."
