#!/bin/bash

set -e

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
CONFIG_DIR="$ROOT_DIR/config"      
DATA_DIR="$ROOT_DIR/data"          
DOWNLOAD_DIR="$DATA_DIR/downloads"
COUNTRY_CODE="${1:-DE}"  # Default to DE 
: "${CHUNK_SIZE:=1000000}"    
mkdir -p "$DATA_DIR" "$DOWNLOAD_DIR"


# --- Utility: Download only if missing or newer ---
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

# Step 1: Setup
echo "[process 1/18] Processing country: $COUNTRY_CODE"

# Step 2: Download countryInfo.txt
echo "[process 2/18] Downloading countryInfo.txt for $COUNTRY_CODE..."
conditional_download "https://download.geonames.org/export/dump/countryInfo.txt" "$DOWNLOAD_DIR/countryInfo.txt"

# Step 3: Validate country code
echo "[process 3/18] Validating country code: $COUNTRY_CODE"
if [ "$COUNTRY_CODE" != "allCountries" ] && ! grep -q -w "^$COUNTRY_CODE" "$DOWNLOAD_DIR/countryInfo.txt"; then
    echo "Error: Invalid country code '$COUNTRY_CODE'."
    echo "Valid codes are: allCountries "
    grep -v '^#' "$DOWNLOAD_DIR/countryInfo.txt" | awk '{print $1}' | tr '\n' ' '
    echo
    exit 1
fi

# Step 4: Clear old data
echo "[process 4/18] Cleaning up previous data files for $COUNTRY_CODE..."
rm -rf "$DATA_DIR/geonames_${COUNTRY_CODE}.csv" temp 2>/dev/null

# Step 5: Download & merge base country file(s)
for cfile in $COUNTRY_CODE; do
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
    echo "  - Appending $cfile.txt to geonames_${COUNTRY_CODE}.csv..."
    cat "$cfile.txt" >> "$DATA_DIR/geonames_${COUNTRY_CODE}.csv"
    cd ..
    rm -rf temp
done

# Step 6: Add admin division keys
echo "[process 6/18] Creating foreign keys for administrative divisions for $COUNTRY_CODE..."
awk 'BEGIN{FS=OFS="\t"} {print $0, $9"."$11, ($12 != "" ? $9"."$11"."$12 : "NONE" )}' "$DATA_DIR/geonames_${COUNTRY_CODE}.csv" > "$DATA_DIR/geonamesplus_${COUNTRY_CODE}.csv"
rm "$DATA_DIR/geonames_${COUNTRY_CODE}.csv"

# Step 7: Extract geoname IDs for filtering
echo "[process 7/18] Extracting geonameIDs for alternate names filtering for $COUNTRY_CODE..."
awk -F'\t' 'NR>1 {print $1}' "$DATA_DIR/geonamesplus_${COUNTRY_CODE}.csv" > "$DATA_DIR/geonameids_${COUNTRY_CODE}.txt"

# Step 8: Filter alternate names for country
echo "[process 8/18] Downloading and filtering alternate names data for $COUNTRY_CODE..."
conditional_download "https://download.geonames.org/export/dump/alternateNamesV2.zip" "$DOWNLOAD_DIR/alternateNamesV2.zip"
mkdir -p temp
cd temp
echo "  - Unzipping alternateNamesV2.zip..."
unzip -qo "$DOWNLOAD_DIR/alternateNamesV2.zip" alternateNamesV2.txt
if [ ! -f "alternateNamesV2.txt" ]; then
    echo "Error: alternateNamesV2.txt not found after unzipping!"
    exit 1
fi
echo "  - Filtering alternateNamesV2.txt for geonameIDs of $COUNTRY_CODE..."
# AWK filter:
# - Load valid geoname IDs
# - Keep only matching rows
# - Normalize row length (10 fields)
awk -F'\t' -v OFS='\t' 'NR==FNR {ids[$1]; next} $2 in ids {for(i=NF+1;i<=10;i++) $i=""; print}' \
    "$DATA_DIR/geonameids_${COUNTRY_CODE}.txt" alternateNamesV2.txt > "$DATA_DIR/alternateNamesV2_${COUNTRY_CODE}.csv"
cd ..
rm -rf temp

# Step 9: Split alternate names into chunks
echo "[process 9/18] Splitting alternate names into chunks for $COUNTRY_CODE..."
split -l $CHUNK_SIZE --numeric-suffixes=1 --additional-suffix=.csv \
  "$DATA_DIR/alternateNamesV2_${COUNTRY_CODE}.csv" "$DATA_DIR/alternateNamesV2_${COUNTRY_CODE}_"
for f in "$DATA_DIR"/alternateNamesV2_${COUNTRY_CODE}_*.csv; do
  [ -f "$f" ] || continue
  echo "  - Adding headers to $f"
  mv "$f" "${f%.csv}.tmp"
  cat "$CONFIG_DIR/headers-alternateNamesV2.csv" "${f%.csv}.tmp" > "$f"
  rm "${f%.csv}.tmp"
done

# Step 10: Prepare admin1 codes
echo "[process 10/18] Downloading and processing admin1 codes..."
cp "$CONFIG_DIR/headers-admin1-codes.csv" "$DATA_DIR/admin1-codes.csv"
conditional_download "https://download.geonames.org/export/dump/admin1CodesASCII.txt" "$DOWNLOAD_DIR/admin1CodesASCII.txt"
cat "$DOWNLOAD_DIR/admin1CodesASCII.txt" >> "$DATA_DIR/admin1-codes.csv"

# Step 11: Prepare admin2 codes
echo "[process 11/18] Downloading and processing admin2 codes..."
cp "$CONFIG_DIR/headers-admin2-codes.csv" "$DATA_DIR/admin2-codes.csv"
conditional_download "https://download.geonames.org/export/dump/admin2Codes.txt" "$DOWNLOAD_DIR/admin2Codes.txt"
cat "$DOWNLOAD_DIR/admin2Codes.txt" >> "$DATA_DIR/admin2-codes.csv"

# Step 12: Extract admin3/admin4 from geonames
echo "[process 12/18] Generating admin3 and admin4 codes for $COUNTRY_CODE..."
awk -F'\t' '($7=="A" && $8=="ADM3") {print $9 "." $11 "." $12 "." $13 "\t" $2 "\t" $3 "\t" $1}' "$DATA_DIR/geonamesplus_${COUNTRY_CODE}.csv" > "$DATA_DIR/admin3-codes.txt"
awk -F'\t' '($7=="A" && $8=="ADM4") {print $9 "." $11 "." $12 "." $13 "." $14 "\t" $2 "\t" $3 "\t" $1}' "$DATA_DIR/geonamesplus_${COUNTRY_CODE}.csv" > "$DATA_DIR/admin4-codes.txt"

# Step 13: Add headers to admin3/admin4 + extract country info
echo "[process 13/18] Adding headers to admin3/admin4 files and extracting country information for $COUNTRY_CODE..."
printf "admin3code\tname\tasciiname\tgeonameId\n" | cat - "$DATA_DIR/admin3-codes.txt" > "$DATA_DIR/admin3-codes.csv"
printf "admin4code\tname\tasciiname\tgeonameId\n" | cat - "$DATA_DIR/admin4-codes.txt" > "$DATA_DIR/admin4-codes.csv"
rm "$DATA_DIR/admin3-codes.txt" "$DATA_DIR/admin4-codes.txt"

# Extract main country records (class A + code PCLI)
awk -F'\t' '($7=="A" && $8=="PCLI"){print $1 "\t" $9 "\t" $2}' "$DATA_DIR/geonamesplus_${COUNTRY_CODE}.csv" > "$DATA_DIR/country-codes.txt"
printf "countryId\tcountryCode\tname\n" | cat - "$DATA_DIR/country-codes.txt" > "$DATA_DIR/country-codes.csv"
rm "$DATA_DIR/country-codes.txt"

# Step 14: Process hierarchy data
echo "[process 14/18] Downloading and processing hierarchy data for $COUNTRY_CODE..."
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
tail -n +2 "$DATA_DIR/country-codes.csv" | cut -f1 > "$DATA_DIR/country-ids.txt"
awk -F'\t' 'NR==FNR {c[$1]; next} ($2 in c)' "$DATA_DIR/country-ids.txt" "$DATA_DIR/hierarchy.csv" > "$DATA_DIR/country-parent-features.csv"
echo -e "parentId\tchildId\ttype" | cat - "$DATA_DIR/country-parent-features.csv" > "$DATA_DIR/country-parent-features-with-header.csv"
rm "$DATA_DIR/country-parent-features.csv"

# Step 15: Compute best English alternate names
echo "[process 15/18] Computing best English alternate names for $COUNTRY_CODE..."
source "$SCRIPT_DIR/compute-bestnames.sh" "$COUNTRY_CODE"
 
#Step 16: Split geonamesplus into chunks
echo "[process 16/18] Splitting data with best names into chunks of $CHUNK_SIZE records each for $COUNTRY_CODE..."
rm -rf "$DATA_DIR"/geonames_${COUNTRY_CODE}_*
tail -n +2 "$DATA_DIR/geonamesplus_${COUNTRY_CODE}.csv" | \
    split -l $CHUNK_SIZE - "$DATA_DIR/geonames_${COUNTRY_CODE}_"

# Step 17: Add headers to chunks
echo "[process 17/18] Adding headers to each chunk for $COUNTRY_CODE..."
for f in "$DATA_DIR"/geonames_${COUNTRY_CODE}_*; do
    [ -f "$f" ] || continue
    echo "  - Adding header to $f"
    csvfile="${f}.csv"
    cat "$CONFIG_DIR/headers-gn.csv" > "$csvfile"
    cat "$f" >> "$csvfile"
    rm "$f"
done

# Step 18: Germany-specific AGS Mapping (DE only)
if [ "$COUNTRY_CODE" = "DE" ]; then
  echo "[process 18/18] Creating AGS lookup (DE only)..."
  awk -F'\t' -v OFS="\t" -v country="DE" -v mapfile="$CONFIG_DIR/admin1_ags_map.txt" '
    BEGIN {
      print "geonameid\tags"
      # Load external admin1 → AGS mapping
      while ((getline < mapfile) > 0) {
        split($0, kv, " ")
        if (kv[1] != "") admin1ags[kv[1]] = kv[2]
      }
      close(mapfile)
    }
    # Build header index for column lookup
    NR==1 { for (i=1; i<=NF; i++) hdr[$i] = i; next }
    # Select only German admin boundaries (ADM1–ADM4)
    $hdr["country code"] == country &&
    $hdr["feature class"] == "A" &&
    ($hdr["feature code"] ~ /ADM[1-4]/) {
      ags=""
      # Prefer ADM4 → ADM3 → ADM2 → ADM1 (ADM1 via mapping)
      if ($hdr["admin4 code"] != "" && $hdr["admin4 code"] != "NONE") ags=$hdr["admin4 code"]
      else if ($hdr["admin3 code"] != "" && $hdr["admin3 code"] != "NONE") ags=$hdr["admin3 code"]
      else if ($hdr["admin2 code"] != "" && $hdr["admin2 code"] != "NONE") ags=$hdr["admin2 code"]
      else if ($hdr["admin1 code"] != "" && $hdr["admin1 code"] != "NONE") ags=admin1ags[$hdr["admin1 code"]]
      if (ags != "" && ags != "NONE") print $hdr["geonameid"], ags
    }
  ' "$DATA_DIR/geonames_DE_aa.csv" > "$DATA_DIR/ags-lookup.csv"
fi

echo "Geonames data processing complete for $COUNTRY_CODE! All files are ready in $DATA_DIR"