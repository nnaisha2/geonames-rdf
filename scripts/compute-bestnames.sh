#!/bin/bash
set -e
#
# compute-bestnames.sh
#
# This script extracts the best English alternate names from GeoNames alternateNamesV2 files,
# and joins them with the main geonamesplus dataset, adding a 'bestName' column.
# It OVERWRITES geonamesplus_<COUNTRY_CODE>.csv with the new version, so downstream scripts
# (like map.sh) continue to work without changes.

#
# Output:
#   - bestnames_<COUNTRY_CODE>.txt 
#   - geonamesplus_<COUNTRY_CODE>.csv (main geonamesplus file with added bestName column)
#

# --- Configuration Section ---
country_files="${1:-DE}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
DATA_DIR="$ROOT_DIR/data"

# --- Step 0: Combine All Alternate Names Chunks ---
echo " Combining all alternateNamesV2_${country_files}_*.csv chunks..."
combined_altfile="$DATA_DIR/alternateNamesV2_${country_files}.csv"
first_chunk=$(ls "$DATA_DIR"/alternateNamesV2_"${country_files}"_*.csv 2>/dev/null | head -1)

if [ -z "$first_chunk" ]; then
    echo "ERROR: No alternateNamesV2_${country_files}_*.csv files found in $DATA_DIR"
    exit 1
fi

# Combine: keep header from first chunk, then all data rows from all chunks
head -1 "$first_chunk" > "$combined_altfile"
tail -n +2 -q "$DATA_DIR"/alternateNamesV2_"${country_files}"_*.csv >> "$combined_altfile"


# --- Step 1: Extract Best English Alternate Names ---
echo "Extracting best English alternate names..."
awk -F'\t' '
NR==1 {
    # Identify column indices by header names
    for(i=1;i<=NF;i++) {
        if($i=="geonameid") gid_col=i
        if($i=="isolanguage") lang_col=i
        if($i=="isPreferredName") pref_col=i
        if($i=="alternateName") name_col=i
    }
    next
}
{
    gid = $gid_col
    lang = $lang_col
    pref = $pref_col
    name = $name_col
    # If English and preferred, use as best name (if not already set)
    if(lang == "en" && pref == "1") {
        if(!(gid in best)) {
            best[gid] = name
            done[gid] = 1
        }
    } else if(lang == "en" && !(gid in best)) {
        # Fallback: first English name if no preferred found
        best[gid] = name
    }
}
END {
    for(gid in best) print gid "\t" best[gid]
}
' "$combined_altfile" > "$DATA_DIR/bestnames_${country_files}.txt"


# --- Step 2: Join with Main Geonames Data and OVERWRITE geonamesplus_<COUNTRY_CODE>.csv ---
echo "Joining best names with main geonamesplus data and overwriting file..."
mainfile="$DATA_DIR/geonamesplus_${country_files}.csv"
tmpfile="$DATA_DIR/geonamesplus_${country_files}.tmp"

if [ ! -f "$mainfile" ]; then
    echo "ERROR: Main geonamesplus file not found: $mainfile"
    exit 1
fi

awk -F'\t' 'NR==FNR {best[$1]=$2; next}
NR==1 {print $0 "\tbestName"; next}
{
    gid = $1
    mainname = $2
    if(gid in best) {
        print $0 "\t" best[gid]
    } else {
        print $0 "\t" mainname
    }
}
' "$DATA_DIR/bestnames_${country_files}.txt" "$mainfile" > "$tmpfile"

mv "$tmpfile" "$mainfile"
