#!/bin/bash
set -e

COUNTRY_CODE="${1:-DE}"
UPLOAD_TARGET="${2:-qendpoint}"

echo "[1/3] Downloading..."
COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.download.yml up --build

echo "[2/3] Transforming..."
COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.transform.yml up --build

echo "[3/3] Uploading to $UPLOAD_TARGET..."
if [ "$UPLOAD_TARGET" == "qendpoint" ]; then
  COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.upload.yml up --build
elif [ "$UPLOAD_TARGET" == "graphdb" ]; then
  COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.upload.graphdb.yml up --build
else
  echo "Unknown upload target: $UPLOAD_TARGET"
  exit 1
fi

echo "Pipeline completed successfully."
