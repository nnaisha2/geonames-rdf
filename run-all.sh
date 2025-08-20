#!/bin/bash
set -e
COUNTRY_CODE="${1:-DE}"
UPLOAD_TARGET="${2:-qendpoint}"

echo "[1/3] Downloading..."
COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.download.yml up --build

echo "[2/3] Transforming..."
COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.transform.yml up --build

# Get current date in YYYY-MM-DD format
CURRENT_DATE=$(date +%F)

# Find the first TTL file in output folder excluding pre-optimization files
latest_ttl=$(find output -maxdepth 1 -type f -name "geonames_*.ttl" ! -name "*_pre_optimization*" | head -n1)

if [ -f "$latest_ttl" ]; then
  # Define versioned filenames with country code and date
  versioned="output/geonames_${COUNTRY_CODE}_${CURRENT_DATE}.ttl"

  # Copy original TTL to versioned filename only if different files
  [ "$latest_ttl" != "$versioned" ] && cp "$latest_ttl" "$versioned"

  # Create compressed (.gz) version of TTL file
  gzip -c "$latest_ttl" > "${versioned}.gz"

  # Create/update symlinks for easy access to the versioned files
  ln -sf "$(basename "$versioned")" output/geonames_ALL.ttl
  ln -sf "$(basename "$versioned").gz" output/geonames_ALL.ttl.gz

  # Update the dump date placeholder in the web/index.html file
  sed -i "s/\[DATE\]/$CURRENT_DATE/g" web/index.html

  echo "Updated files for $COUNTRY_CODE on $CURRENT_DATE"
else
  echo "No final TTL file found in output/"
fi

echo "[3/3] Uploading to $UPLOAD_TARGET..."

# Start web server first (in background)
echo "Starting Web Server..."
docker compose -f docker-compose.web.yml up --build -d

if [ "$UPLOAD_TARGET" == "qendpoint" ]; then
  COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.upload.yml up --build
elif [ "$UPLOAD_TARGET" == "graphdb" ]; then
  COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.upload.graphdb.yml up --build
else
  echo "Unknown upload target: $UPLOAD_TARGET"
  exit 1
fi

echo "Pipeline completed successfully."
