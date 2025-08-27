#!/bin/bash
set -e
COUNTRY_CODE="${1:-DE}"
UPLOAD_TARGET="${2:-qendpoint}"

echo "[1/3] Downloading..."
COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.yml up --build geonames-download

echo "[2/3] Transforming..."
COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.yml up --build geonames-transform

# Get current date in YYYY-MM-DD format
CURRENT_DATE=$(date +%F)

# Remove old files for the given COUNTRY_CODE except today's zip and ttl files
find output -maxdepth 1 -type f \( -name "geonames_${COUNTRY_CODE}_*.ttl" -o -name "geonames_${COUNTRY_CODE}_*.ttl.zip" \) \
  ! -name "geonames_${COUNTRY_CODE}_${CURRENT_DATE}.ttl" \
  ! -name "geonames_${COUNTRY_CODE}_${CURRENT_DATE}.ttl.zip" \
  -exec rm -f {} +

# Check the raw TTL file from the transform step
ttl_file="output/geonames_${COUNTRY_CODE}.ttl"

if [ -f "$ttl_file" ]; then
  # Create today's versioned TTL copy
  versioned_ttl="geonames_${COUNTRY_CODE}_${CURRENT_DATE}.ttl"
  cp "$ttl_file" "output/$versioned_ttl"

  # Create the zip compressed archive of that TTL file
  zip -j "output/${versioned_ttl}.zip" "output/$versioned_ttl"

  # Generate fresh index.html from template each run
  cp web/index.template.html web/index.html

  # Replace placeholders with current date and zip filename
  sed -i.bak "s/\[DATE\]/$CURRENT_DATE/g" web/index.html && rm -f web/index.html.bak
  sed -i.bak "s|\[VERSIONED_FILE\]|${versioned_ttl}.zip|g" web/index.html && rm -f web/index.html.bak

  # Download countryInfo.txt if not already present
  curl -sSfR -z data/downloads/countryInfo.txt -o data/downloads/countryInfo.txt https://download.geonames.org/export/dump/countryInfo.txt || true

  # Lookup country name from countryInfo.txt
  if [ "$COUNTRY_CODE" = "allCountries" ]; then
    COUNTRY_NAME="All Countries"
  else
    COUNTRY_NAME=$(awk -F'\t' -v code="$COUNTRY_CODE" '$1 == code {print $5}' data/downloads/countryInfo.txt)
    if [ -z "$COUNTRY_NAME" ]; then
      COUNTRY_NAME="$COUNTRY_CODE"
    fi
  fi
  
  # Replace placeholders with country name
  sed -i.bak "s/\[COUNTRY_NAME\]/$COUNTRY_NAME/g" web/index.html && rm -f web/index.html.bak
  echo "Updated files for $COUNTRY_CODE on $CURRENT_DATE"
else
  echo "No TTL file found at $ttl_file"
  exit 1
fi

echo "[3/3] Uploading to $UPLOAD_TARGET..."

# Start web server first (in background)
echo "Starting Web Server..."
docker compose -f docker-compose.yml up --build -d geonames-web

if [ "$UPLOAD_TARGET" == "qendpoint" ]; then
  COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.yml up --build geonames-upload qendpoint nginx
elif [ "$UPLOAD_TARGET" == "graphdb" ]; then
  COUNTRY_CODE=$COUNTRY_CODE docker compose -f docker-compose.upload.graphdb.yml up --build
else
  echo "Unknown upload target: $UPLOAD_TARGET"
  exit 1
fi

echo "Pipeline completed successfully."
