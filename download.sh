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

country_files="${1:-DE}"  # Accept argument, default to DE
#country_files="allCountries"  # Uncomment to download all countries



echo "[process 0/16] Processing country: $country_files"

echo "[process 1/16] Downloading countryInfo.txt for $country_files..."
# Download countryInfo.txt with conditional check
conditional_download "https://download.geonames.org/export/dump/countryInfo.txt" "$DOWNLOAD_DIR/countryInfo.txt"

echo "[process 2/16] Validating country code: $country_files"
if [ "$country_files" != "allCountries" ] && ! grep -q -w "^$country_files" "$DOWNLOAD_DIR/countryInfo.txt"; then
    echo "Error: Invalid country code '$country_files'."
    echo "Valid codes are: allCountries "
    grep -v '^#' "$DOWNLOAD_DIR/countryInfo.txt" | awk '{print $1}' | tr '\n' ' '
    echo
    exit 1
fi

echo "[process 3/16] Cleaning up previous data files for $country_files..."
rm -rf "$DATA_DIR/geonames_${country_files}.csv" temp 2>/dev/null

# Download and process country files
for cfile in $country_files; do
    echo "[process 4/16] Processing country file: $cfile"
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
    echo "  - Appending $cfile.txt to geonames_${country_files}.csv..."
    cat "$cfile.txt" >> "$DATA_DIR/geonames_${country_files}.csv"
    cd ..
    rm -rf temp
done

echo "[process 5/16] Creating foreign keys for administrative divisions for $country_files..."
awk 'BEGIN{FS=OFS="\t"} {print $0, $9"."$11, ($12 != "" ? $9"."$11"."$12 : "NONE" )}' "$DATA_DIR/geonames_${country_files}.csv" > "$DATA_DIR/geonamesplus_${country_files}.csv"
rm "$DATA_DIR/geonames_${country_files}.csv"

echo "[process 6/16] Splitting data into chunks of $CHUNK_SIZE records each for $country_files..."
rm -rf "$DATA_DIR"/geonames_${country_files}_*
split -l $CHUNK_SIZE "$DATA_DIR/geonamesplus_${country_files}.csv" "$DATA_DIR/geonames_${country_files}_"

echo "[process 7/16] Adding headers to each chunk for $country_files..."
for f in "$DATA_DIR"/geonames_${country_files}_*; do
    [ -f "$f" ] || continue
    echo "  - Processing $f"
    csvfile="${f}.csv"
    cat "$CONFIG_DIR/headers-gn.csv" > "$csvfile"
    cat "$f" >> "$csvfile"
    rm "$f"
done

echo "[process 8/16] Extracting geonameIDs for alternate names filtering for $country_files..."
awk -F'\t' 'NR>1 {print $1}' "$DATA_DIR/geonamesplus_${country_files}.csv" > "$DATA_DIR/geonameids_${country_files}.txt"

echo "[process 9/16] Downloading and filtering alternate names data for $country_files..."
conditional_download "https://download.geonames.org/export/dump/alternateNamesV2.zip" "$DOWNLOAD_DIR/alternateNamesV2.zip"
mkdir -p temp
cd temp
echo "  - Unzipping alternateNamesV2.zip..."
unzip -qo "$DOWNLOAD_DIR/alternateNamesV2.zip" alternateNamesV2.txt
if [ ! -f "alternateNamesV2.txt" ]; then
    echo "Error: alternateNamesV2.txt not found after unzipping!"
    exit 1
fi
echo "  - Filtering alternateNamesV2.txt for geonameIDs of $country_files..."
# The awk command:
# 1. First reads all geonameIDs for the selected country into memory (NR==FNR)
# 2. Then processes alternateNamesV2.txt, keeping only rows where $2 (geonameid) exists in our IDs
# 3. Ensures each output row has exactly 10 fields (some input rows might be incomplete)
awk -F'\t' -v OFS='\t' 'NR==FNR {ids[$1]; next} $2 in ids {for(i=NF+1;i<=10;i++) $i=""; print}' \
    "$DATA_DIR/geonameids_${country_files}.txt" alternateNamesV2.txt > "$DATA_DIR/alternateNamesV2_${country_files}.csv"
cd ..
rm -rf temp

echo "[process 10/16] Splitting alternate names into chunks for $country_files..."
split -l $CHUNK_SIZE --numeric-suffixes=1 --additional-suffix=.csv \
  "$DATA_DIR/alternateNamesV2_${country_files}.csv" "$DATA_DIR/alternateNamesV2_${country_files}_"
for f in "$DATA_DIR"/alternateNamesV2_${country_files}_*.csv; do
  [ -f "$f" ] || continue
  echo "  - Adding headers to $f"
  mv "$f" "${f%.csv}.tmp"
  cat "$CONFIG_DIR/headers-alternateNamesV2.csv" "${f%.csv}.tmp" > "$f"
  rm "${f%.csv}.tmp"
done

echo "[process 11/16] Downloading and processing admin1 codes..."
cp "$CONFIG_DIR/headers-admin1-codes.csv" "$DATA_DIR/admin1-codes.csv"
conditional_download "https://download.geonames.org/export/dump/admin1CodesASCII.txt" "$DOWNLOAD_DIR/admin1CodesASCII.txt"
cat "$DOWNLOAD_DIR/admin1CodesASCII.txt" >> "$DATA_DIR/admin1-codes.csv"

echo "[process 12/16] Downloading and processing admin2 codes..."
cp "$CONFIG_DIR/headers-admin2-codes.csv" "$DATA_DIR/admin2-codes.csv"
conditional_download "https://download.geonames.org/export/dump/admin2Codes.txt" "$DOWNLOAD_DIR/admin2Codes.txt"
cat "$DOWNLOAD_DIR/admin2Codes.txt" >> "$DATA_DIR/admin2-codes.csv"

echo "[process 13/16] Downloading and processing hierarchy data for $country_files..."
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

echo "[process 14/16] Downloading and processing postal code data for $country_files..."
cp "$CONFIG_DIR/headers-PostalCode.csv" "$DATA_DIR/postal-codes-${country_files}.csv"
conditional_download "https://download.geonames.org/export/zip/${country_files}.zip" "$DOWNLOAD_DIR/postal-codes-${country_files}.zip"
mkdir -p temp
cd temp
echo "    - Unzipping postal-codes-${country_files}.zip..."
unzip -qo "$DOWNLOAD_DIR/postal-codes-${country_files}.zip" ${country_files}.txt
if [ ! -f "${country_files}.txt" ]; then
    echo "Error: ${country_files}.txt not found after unzipping!"
    exit 1
fi
cat ${country_files}.txt >> "$DATA_DIR/postal-codes-${country_files}.csv"
cd ..
rm -rf temp

echo "[process 15/16] Generating admin3 and admin4 codes for $country_files..."
awk -F'\t' '($7=="A" && $8=="ADM3") {print $9 "." $11 "." $12 "." $13 "\t" $2 "\t" $3 "\t" $1}' "$DATA_DIR/geonamesplus_${country_files}.csv" > "$DATA_DIR/admin3-codes.txt"
awk -F'\t' '($7=="A" && $8=="ADM4") {print $9 "." $11 "." $12 "." $13 "." $14 "\t" $2 "\t" $3 "\t" $1}' "$DATA_DIR/geonamesplus_${country_files}.csv" > "$DATA_DIR/admin4-codes.txt"

echo "[process 16/16] Adding headers to admin3/admin4 files and extracting country information for $country_files..."
printf "admin3code\tname\tasciiname\tgeonameId\n" | cat - "$DATA_DIR/admin3-codes.txt" > "$DATA_DIR/admin3-codes.csv"
printf "admin4code\tname\tasciiname\tgeonameId\n" | cat - "$DATA_DIR/admin4-codes.txt" > "$DATA_DIR/admin4-codes.csv"
rm "$DATA_DIR/admin3-codes.txt" "$DATA_DIR/admin4-codes.txt"

# Extract country information (feature class "A" and code "PCLI")
awk -F'\t' '($7=="A" && $8=="PCLI"){print $1 "\t" $9 "\t" $2}' "$DATA_DIR/geonamesplus_${country_files}.csv" > "$DATA_DIR/country-codes.txt"
printf "countryId\tcountryCode\tname\n" | cat - "$DATA_DIR/country-codes.txt" > "$DATA_DIR/country-codes.csv"
rm "$DATA_DIR/country-codes.txt"

echo "Geonames data processing complete for $country_files! All files are ready in $DATA_DIR"