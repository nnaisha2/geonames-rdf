#set -x # uncomment for debugging
#!/bin/sh

# This script downloads and processes Geonames data for mapping purposes.
# It handles country-specific data downloads, creates foreign keys, chunks data,
# and ensures files are only downloaded if missing or out-of-date.
# Geonames updates its data regularly, so this script checks for updates before downloading.

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
CONFIG_DIR="$ROOT_DIR/config"      
DATA_DIR="$ROOT_DIR/data"          
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

echo "[process 1/18] Processing country: $country_files"

echo "[process 2/18] Downloading countryInfo.txt for $country_files..."
conditional_download "https://download.geonames.org/export/dump/countryInfo.txt" "$DOWNLOAD_DIR/countryInfo.txt"

echo "[process 3/18] Validating country code: $country_files"
if [ "$country_files" != "allCountries" ] && ! grep -q -w "^$country_files" "$DOWNLOAD_DIR/countryInfo.txt"; then
    echo "Error: Invalid country code '$country_files'."
    echo "Valid codes are: allCountries "
    grep -v '^#' "$DOWNLOAD_DIR/countryInfo.txt" | awk '{print $1}' | tr '\n' ' '
    echo
    exit 1
fi

echo "[process 4/18] Cleaning up previous data files for $country_files..."
rm -rf "$DATA_DIR/geonames_${country_files}.csv" temp 2>/dev/null

# Download and process country files
for cfile in $country_files; do
    echo "[process 5/18] Processing country file: $cfile"
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

echo "[process 6/18] Creating foreign keys for administrative divisions for $country_files..."
awk 'BEGIN{FS=OFS="\t"} {print $0, $9"."$11, ($12 != "" ? $9"."$11"."$12 : "NONE" )}' "$DATA_DIR/geonames_${country_files}.csv" > "$DATA_DIR/geonamesplus_${country_files}.csv"
rm "$DATA_DIR/geonames_${country_files}.csv"

echo "[process 7/18] Extracting geonameIDs for alternate names filtering for $country_files..."
awk -F'\t' 'NR>1 {print $1}' "$DATA_DIR/geonamesplus_${country_files}.csv" > "$DATA_DIR/geonameids_${country_files}.txt"

echo "[process 8/18] Downloading and filtering alternate names data for $country_files..."
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

echo "[process 9/18] Splitting alternate names into chunks for $country_files..."
split -l $CHUNK_SIZE --numeric-suffixes=1 --additional-suffix=.csv \
  "$DATA_DIR/alternateNamesV2_${country_files}.csv" "$DATA_DIR/alternateNamesV2_${country_files}_"
for f in "$DATA_DIR"/alternateNamesV2_${country_files}_*.csv; do
  [ -f "$f" ] || continue
  echo "  - Adding headers to $f"
  mv "$f" "${f%.csv}.tmp"
  cat "$CONFIG_DIR/headers-alternateNamesV2.csv" "${f%.csv}.tmp" > "$f"
  rm "${f%.csv}.tmp"
done

echo "[process 10/18] Downloading and processing admin1 codes..."
cp "$CONFIG_DIR/headers-admin1-codes.csv" "$DATA_DIR/admin1-codes.csv"
conditional_download "https://download.geonames.org/export/dump/admin1CodesASCII.txt" "$DOWNLOAD_DIR/admin1CodesASCII.txt"
cat "$DOWNLOAD_DIR/admin1CodesASCII.txt" >> "$DATA_DIR/admin1-codes.csv"

echo "[process 11/18] Downloading and processing admin2 codes..."
cp "$CONFIG_DIR/headers-admin2-codes.csv" "$DATA_DIR/admin2-codes.csv"
conditional_download "https://download.geonames.org/export/dump/admin2Codes.txt" "$DOWNLOAD_DIR/admin2Codes.txt"
cat "$DOWNLOAD_DIR/admin2Codes.txt" >> "$DATA_DIR/admin2-codes.csv"

echo "[process 12/18] Generating admin3 and admin4 codes for $country_files..."
awk -F'\t' '($7=="A" && $8=="ADM3") {print $9 "." $11 "." $12 "." $13 "\t" $2 "\t" $3 "\t" $1}' "$DATA_DIR/geonamesplus_${country_files}.csv" > "$DATA_DIR/admin3-codes.txt"
awk -F'\t' '($7=="A" && $8=="ADM4") {print $9 "." $11 "." $12 "." $13 "." $14 "\t" $2 "\t" $3 "\t" $1}' "$DATA_DIR/geonamesplus_${country_files}.csv" > "$DATA_DIR/admin4-codes.txt"

echo "[process 13/18] Adding headers to admin3/admin4 files and extracting country information for $country_files..."
printf "admin3code\tname\tasciiname\tgeonameId\n" | cat - "$DATA_DIR/admin3-codes.txt" > "$DATA_DIR/admin3-codes.csv"
printf "admin4code\tname\tasciiname\tgeonameId\n" | cat - "$DATA_DIR/admin4-codes.txt" > "$DATA_DIR/admin4-codes.csv"
rm "$DATA_DIR/admin3-codes.txt" "$DATA_DIR/admin4-codes.txt"

# Extract country information (feature class "A" and code "PCLI")
awk -F'\t' '($7=="A" && $8=="PCLI"){print $1 "\t" $9 "\t" $2}' "$DATA_DIR/geonamesplus_${country_files}.csv" > "$DATA_DIR/country-codes.txt"
printf "countryId\tcountryCode\tname\n" | cat - "$DATA_DIR/country-codes.txt" > "$DATA_DIR/country-codes.csv"
rm "$DATA_DIR/country-codes.txt"

echo "[process 14/18] Downloading and processing hierarchy data for $country_files..."
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

echo "Filtering hierarchy for country-level relationships..."

# Extract country geonameIds (skip header)
tail -n +2 "$DATA_DIR/country-codes.csv" | cut -f1 > "$DATA_DIR/country-ids.txt"
# Filter hierarchy for country-level relationships
awk -F'\t' 'NR==FNR {c[$1]; next} ($2 in c)' "$DATA_DIR/country-ids.txt" "$DATA_DIR/hierarchy.csv" > "$DATA_DIR/country-parent-features.csv"
# Add header
echo -e "parentId\tchildId\ttype" | cat - "$DATA_DIR/country-parent-features.csv" > "$DATA_DIR/country-parent-features-with-header.csv"
rm "$DATA_DIR/country-parent-features.csv"

echo "[process 15/18] Computing best English alternate names for $country_files..."
source "$SCRIPT_DIR/compute-bestnames.sh""$country_files"
 

echo "[process 16/18] Splitting data with best names into chunks of $CHUNK_SIZE records each for $country_files..."
rm -rf "$DATA_DIR"/geonames_${country_files}_*

# Skip header for chunking, add it back after
tail -n +2 "$DATA_DIR/geonamesplus_${country_files}.csv" | \
    split -l $CHUNK_SIZE - "$DATA_DIR/geonames_${country_files}_"

echo "[process 17/18] Adding headers to each chunk for $country_files..."
for f in "$DATA_DIR"/geonames_${country_files}_*; do
    [ -f "$f" ] || continue
    echo "  - Adding header to $f"
    csvfile="${f}.csv"
    cat "$CONFIG_DIR/headers-gn.csv" > "$csvfile"
    cat "$f" >> "$csvfile"
    rm "$f"
done

# Purpose:
# This block generates a lookup CSV mapping geoname IDs to official German administrative region codes (AGS)
# only if the target country is Germany ("DE"). It processes a geonames TSV dataset specific to Germany.
# Approach:
# - Loads an external mapping from admin1 codes to AGS codes.
# - Reads the geonames file header once to index columns by name for clarity.
# - For each German record, selects the most detailed administrative code available from admin4 down to admin1.
#   For admin1, the code uses the loaded mapping to get the correct AGS.
# - Outputs a two-column tab-separated file with geonameid and the resolved AGS code.
# Notes:
# - The hierarchy of administrative codes is checked in decreasing specificity to ensure the best match.
# - Lines with missing or "NONE" admin codes are ignored to avoid invalid mappings.

if [ "$country_files" = "DE" ]; then
  echo "[process 18/18] Creating AGS lookup csv for DE..."

  awk -F'\t' -v OFS="\t" -v country="DE" \
      -v mapfile="$CONFIG_DIR/admin1_ags_map.txt" '

  BEGIN {
    # Print header line in output CSV (tab-separated)
    print "geonameid\tags"

    # Load admin1 → AGS mapping from the mapfile into an array
    while ((getline < mapfile) > 0) {
      split($0, kv, " ")         # split each line into key/value by space
      if (length(kv[1]))         # ignore empty keys
        admin1ags[kv[1]] = kv[2] # store mapping in array
    }
    close(mapfile)
  }

  NR==1 {
    # Store the column index for each header name for quick lookup
    for (i=1; i<=NF; i++)
      hdr[$i] = i
    next # skip processing this header row
  }

  # PROCESSING FILTER:
  # 1. Country must match "DE"
  # 2. Feature class must be "A" (Administrative boundary)
  # 3. Feature code must be one of ADM1–ADM4
  $hdr["country code"] == country &&
  $hdr["feature class"] == "A" &&
  ($hdr["feature code"] == "ADM1" ||
   $hdr["feature code"] == "ADM2" ||
   $hdr["feature code"] == "ADM3" ||
   $hdr["feature code"] == "ADM4") {

    ags = "" # reset AGS variable for this row

    # Choose the most specific available admin code
    if ($hdr["admin4 code"] != "" && $hdr["admin4 code"] != "NONE")
      ags = $hdr["admin4 code"]
    else if ($hdr["admin3 code"] != "" && $hdr["admin3 code"] != "NONE")
      ags = $hdr["admin3 code"]
    else if ($hdr["admin2 code"] != "" && $hdr["admin2 code"] != "NONE")
      ags = $hdr["admin2 code"]
    else if ($hdr["admin1 code"] != "" && $hdr["admin1 code"] != "NONE")
      ags = admin1ags[$hdr["admin1 code"]] # look up mapped AGS

    # If AGS is found and valid, print geonameid + AGS
    if (ags != "" && ags != "NONE")
      print $hdr["geonameid"], ags
  }
  ' "$DATA_DIR/geonames_DE_aa.csv" > "$DATA_DIR/ags-lookup.csv"
fi

echo "Geonames data processing complete for $country_files! All files are ready in $DATA_DIR"