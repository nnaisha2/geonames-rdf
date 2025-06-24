#set -x # uncomment for debugging
#!/bin/sh

# This script downloads and processes Geonames data for mapping purposes.
# It handles country-specific data downloads, creates foreign keys, chunks data,
# and ensures files are only downloaded if missing or out-of-date.
# Geonames updates its data regularly, so this script checks for updates before downloading.

set -e

# Configuration
CONFIG_DIR="$PWD/config"      
DATA_DIR="$PWD/data"          
DOWNLOAD_DIR="$DATA_DIR/downloads" 
: "${CHUNK_SIZE:=1000000}"    
mkdir -p "$DATA_DIR" "$DOWNLOAD_DIR"

# Download with conditional check using HTTP Last-Modified headers
conditional_download() {
    local url=$1
    local local_file=$2
    echo -n "Checking $local_file... "
    if [ -f "$local_file" ]; then
        local before=$(stat -c %Y "$local_file")
        curl -sSfR -z "$local_file" -o "$local_file" "$url"
        local after=$(stat -c %Y "$local_file")
        if [ "$before" != "$after" ]; then
            echo "updated"
        else
            echo "already current"
        fi
    else
        if curl -sSfR -o "$local_file" "$url"; then
            echo "downloaded"
        else
            echo "error"
            exit 1
        fi
    fi
}

# Specify countries to download (currently only Germany)
country_files="DE "
#country_files="allCountries"  # Uncomment to download all countries

echo "[process 1/15] Cleaning up previous data files..."
rm -rf "$DATA_DIR/geonames.csv" temp 2>/dev/null

# Download and process country files
for cfile in $country_files; do
    echo "[process 2/15] Processing country file: $cfile"
    conditional_download "https://download.geonames.org/export/dump/$cfile.zip" "$DOWNLOAD_DIR/$cfile.zip"
    # Ensure download succeeded
    if [ ! -f "$DOWNLOAD_DIR/$cfile.zip" ]; then
        echo "Error: Failed to download $cfile.zip"
        exit 1
    fi
    mkdir -p temp
    cd temp
    echo "  - Unzipping $cfile.zip..."
    unzip -qo "$DOWNLOAD_DIR/$cfile.zip"
    if [ ! -f "$cfile.txt" ]; then
        echo "Error: $cfile.txt not found after unzipping!"
        exit 1
    fi
    mkdir -p "$DATA_DIR"
    echo "  - Appending $cfile.txt to geonames.csv..."
    cat "$cfile.txt" >> "$DATA_DIR/geonames.csv"
    cd ..
    rm -rf temp
done

# Create foreign keys 'adm1' and 'adm2' for the admin1code and admin2code tables
echo "[process 3/15] Creating foreign keys for administrative divisions..."
awk 'BEGIN{FS=OFS="\t"} {print $0, $9"."$11, ($12 != "" ? $9"."$11"."$12 : "NONE" )}' "$DATA_DIR/geonames.csv" > "$DATA_DIR/geonamesplus.csv"
rm "$DATA_DIR/geonames.csv"

# Split the large file into manageable chunks
echo "[process 4/15] Splitting data into chunks of $CHUNK_SIZE records each..."
rm -rf "$DATA_DIR"/geonames_*
split -l $CHUNK_SIZE "$DATA_DIR/geonamesplus.csv" "$DATA_DIR/geonames_"

# Add header row to each chunk
echo "[process 5/15] Adding headers to each chunk..."
for f in "$DATA_DIR"/geonames_*; do
    [ -f "$f" ] || continue
    echo "  - Processing $f"
    csvfile="${f}.csv"
    cat "$CONFIG_DIR/headers-gn.csv" > "$csvfile"
    cat "$f" >> "$csvfile"
    rm "$f"
done

# Extract German geonameIDs for alternate names processing
echo "[process 6/15] Extracting German geonameIDs for alternate names filtering..."
awk -F'\t' 'NR>1 {print $1}' "$DATA_DIR/geonamesplus.csv" > "$DATA_DIR/geonameids_de.txt"

# Download and filter alternateNamesV2 for Germany
echo "[process 7/15] Downloading and filtering alternate names data..."
conditional_download "https://download.geonames.org/export/dump/alternateNamesV2.zip" "$DOWNLOAD_DIR/alternateNamesV2.zip"
mkdir -p temp
cd temp
echo "  - Unzipping alternateNamesV2.zip..."
unzip -qo "$DOWNLOAD_DIR/alternateNamesV2.zip" alternateNamesV2.txt
if [ ! -f "alternateNamesV2.txt" ]; then
    echo "Error: alternateNamesV2.txt not found after unzipping!"
    exit 1
fi
echo "  - Filtering alternateNamesV2.txt for German geonameIDs..."
awk -F'\t' -v OFS='\t' 'NR==FNR {ids[$1]; next} $2 in ids {for(i=NF+1;i<=10;i++) $i=""; print}' \
    "$DATA_DIR/geonameids_de.txt" alternateNamesV2.txt > "$DATA_DIR/alternateNamesV2_DE.csv"
cd ..
rm -rf temp

# Split alternate names into chunks
echo "[process 8/15] Splitting alternate names into chunks..."
split -l $CHUNK_SIZE --numeric-suffixes=1 --additional-suffix=.csv \
  "$DATA_DIR/alternateNamesV2_DE.csv" "$DATA_DIR/alternateNamesV2_DE_"
for f in "$DATA_DIR"/alternateNamesV2_DE_*.csv; do
  [ -f "$f" ] || continue
  echo "  - Adding headers to $f"
  mv "$f" "${f%.csv}.tmp"
  cat "$CONFIG_DIR/headers-alternateNamesV2.csv" "${f%.csv}.tmp" > "$f"
  rm "${f%.csv}.tmp"
done

# Download and process supporting administrative files
echo "[process 9/15] Downloading and processing admin1 codes..."
cp "$CONFIG_DIR/headers-admin1-codes.csv" "$DATA_DIR/admin1-codes.csv"
conditional_download "https://download.geonames.org/export/dump/admin1CodesASCII.txt" "$DOWNLOAD_DIR/admin1CodesASCII.txt"
cat "$DOWNLOAD_DIR/admin1CodesASCII.txt" >> "$DATA_DIR/admin1-codes.csv"

echo "[process 10/15] Downloading and processing admin2 codes..."
cp "$CONFIG_DIR/headers-admin2-codes.csv" "$DATA_DIR/admin2-codes.csv"
conditional_download "https://download.geonames.org/export/dump/admin2Codes.txt" "$DOWNLOAD_DIR/admin2Codes.txt"
cat "$DOWNLOAD_DIR/admin2Codes.txt" >> "$DATA_DIR/admin2-codes.csv"

echo "[process 11/15] Downloading and processing hierarchy data..."
cp "$CONFIG_DIR/headers-hierarchy.csv" "$DATA_DIR/hierarchy.csv"
conditional_download "https://download.geonames.org/export/dump/hierarchy.zip" "$DOWNLOAD_DIR/hierarchy.zip"
mkdir -p temp
cd temp
echo "    - Unzipping hierarchy.zip..."
unzip -qo "$DOWNLOAD_DIR/hierarchy.zip" hierarchy.txt
if [ ! -f "hierarchy.txt" ]; then
    echo "Error: hierarchy.txt not found after unzipping!"
    exit 1
fi
cat hierarchy.txt >> "$DATA_DIR/hierarchy.csv"
cd ..
rm -rf temp

echo "[process 12/15] Downloading and processing postal code data for Germany..."
cp "$CONFIG_DIR/headers-PostalCode.csv" "$DATA_DIR/postal-codes-DE.csv"
conditional_download "https://download.geonames.org/export/zip/DE.zip" "$DOWNLOAD_DIR/postal-codes-DE.zip"
mkdir -p temp
cd temp
echo "    - Unzipping postal-codes-DE.zip..."
unzip -qo "$DOWNLOAD_DIR/postal-codes-DE.zip" DE.txt
if [ ! -f "DE.txt" ]; then
    echo "Error: DE.txt not found after unzipping!"
    exit 1
fi
cat DE.txt >> "$DATA_DIR/postal-codes-DE.csv"
cd ..
rm -rf temp

# Create admin3 and admin4 codes from geonames data
echo "[process 13/15] Generating admin3 and admin4 codes..."
awk -F'\t' '($7=="A" && $8=="ADM3") {print $9 "." $11 "." $12 "." $13 "\t" $2 "\t" $3 "\t" $1}' "$DATA_DIR/geonamesplus.csv" > "$DATA_DIR/admin3-codes.txt"
awk -F'\t' '($7=="A" && $8=="ADM4") {print $9 "." $11 "." $12 "." $13 "." $14 "\t" $2 "\t" $3 "\t" $1}' "$DATA_DIR/geonamesplus.csv" > "$DATA_DIR/admin4-codes.txt"

echo "[process 14/15] Adding headers to admin3/admin4 files..."
printf "admin3code\tname\tasciiname\tgeonameId\n" | cat - "$DATA_DIR/admin3-codes.txt" > "$DATA_DIR/admin3-codes.csv"
printf "admin4code\tname\tasciiname\tgeonameId\n" | cat - "$DATA_DIR/admin4-codes.txt" > "$DATA_DIR/admin4-codes.csv"
rm "$DATA_DIR/admin3-codes.txt" "$DATA_DIR/admin4-codes.txt"

# Extract country information (feature class "A" and code "PCLI")
echo "[process 15/15] Extracting country information..."
awk -F'\t' '($7=="A" && $8=="PCLI"){print $1 "\t" $9 "\t" $2}' "$DATA_DIR/geonamesplus.csv" > "$DATA_DIR/country-codes.txt"
printf "countryId\tcountryCode\tname\n" | cat - "$DATA_DIR/country-codes.txt" > "$DATA_DIR/country-codes.csv"
rm "$DATA_DIR/country-codes.txt"

echo "Geonames data processing complete! All files are ready in $DATA_DIR"