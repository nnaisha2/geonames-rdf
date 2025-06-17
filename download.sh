#!/bin/sh

# This script downloads and processes Geonames data for mapping purposes.
# It handles country-specific data downloads, creates foreign keys, chunks data,

# Configuration
CONFIG_DIR="$PWD/config"      # Directory containing header files
DATA_DIR="$PWD/data"          # Directory for storing downloaded data
: "${CHUNK_SIZE:=1000000}"    # Default chunk size for splitting files
mkdir -p $DATA_DIR            


# Specify countries to download (currently only Germany)
country_files="DE "
#country_files="allCountries"  # Uncomment to download all countries

echo "Cleaning up previous data files..."
rm -rf $DATA_DIR/geonames.csv temp

# Download and process country files
for cfile in $country_files; do
    echo "Processing country file: $cfile"
    echo "  - Downloading $cfile.zip from Geonames..."
    mkdir temp
    cd temp
    curl -sSO "https://download.geonames.org/export/dump/$cfile.zip"
    
    echo "  - Unzipping and concatenating data..."
    unzip "$cfile.zip"
    cat "$cfile.txt" >> $DATA_DIR/geonames.csv
    cd ..
    rm -rf temp
done

# Create foreign keys 'adm1' and 'adm2' for the admin1code and admin2code tables
# The awk command:
# - Processes tab-separated input/output (FS=OFS="\t")
# - Adds two new columns to each row:
#   1. $9 (country code) + "." + $11 (admin1 code)
#   2. Either $9.$11.$12 (if admin2 exists) or "NONE" (explicit for better query performance)
# This avoids the need for OPTIONAL joins which would slow down mapping
echo "Creating foreign keys for administrative divisions..."
awk 'BEGIN{FS=OFS="\t"} {print $0, $9"."$11, ($12 != "" ? $9"."$11"."$12 : "NONE" )}' $DATA_DIR/geonames.csv > $DATA_DIR/geonamesplus.csv
rm $DATA_DIR/geonames.csv

# Split the large file into manageable chunks
echo "Splitting data into chunks of $CHUNK_SIZE records each..."
rm -rf $DATA_DIR/geonames_*
split -l $CHUNK_SIZE $DATA_DIR/geonamesplus.csv $DATA_DIR/geonames_

# Add header row to each chunk
echo "Adding headers to each chunk..."
for f in $DATA_DIR/geonames_*; do
    echo "  - Processing $f"
    csvfile="${f}.csv"
    cat $CONFIG_DIR/headers-gn.csv > $csvfile
    cat $f >> $csvfile
    rm $f
done


# This awk command processes each line of the input file(s) and applies the given pattern or action.
# Extract German geonameIDs for alternate names processing
echo "Extracting German geonameIDs for alternate names filtering..."
# The awk command:
# 1. First reads all German geonameIDs into memory (NR==FNR)
# 2. Then processes alternateNamesV2.txt, keeping only rows where $2 (geonameid) exists in our German IDs
# 3. Ensures each output row has exactly 10 fields (some input rows might be incomplete)

awk -F'\t' 'NR>1 {print $1}' "$DATA_DIR/geonamesplus.csv" > "$DATA_DIR/geonameids_de.txt"

# Download and filter alternateNamesV2 for Germany
echo "Downloading and filtering alternate names data..."
curl -sS "https://download.geonames.org/export/dump/alternateNamesV2.zip" -o alternateNamesV2.zip
unzip -o alternateNamesV2.zip alternateNamesV2.txt

echo "Processing alternate names to match German locations..."
awk -F'\t' -v OFS='\t' 'NR==FNR {ids[$1]; next} $2 in ids {for(i=NF+1;i<=10;i++) $i=""; print}' "$DATA_DIR/geonameids_de.txt" alternateNamesV2.txt > "$DATA_DIR/alternateNamesV2_DE.csv"
rm alternateNamesV2.zip alternateNamesV2.txt

# Split alternate names into chunks
echo "Splitting alternate names into chunks..."
split -l $CHUNK_SIZE --numeric-suffixes=1 --additional-suffix=.csv \
  "$DATA_DIR/alternateNamesV2_DE.csv" "$DATA_DIR/alternateNamesV2_DE_"
for f in "$DATA_DIR"/alternateNamesV2_DE_*.csv; do
  echo "  - Adding headers to $f"
  mv "$f" "${f%.csv}.tmp"
  cat "$CONFIG_DIR/headers-alternateNamesV2.csv" "${f%.csv}.tmp" > "$f"
  rm "${f%.csv}.tmp"
done

# Download and process supporting administrative files
echo "Downloading and processing supporting administrative files..."

echo "  - Processing admin1 codes..."
cp $CONFIG_DIR/headers-admin1-codes.csv $DATA_DIR/admin1-codes.csv
curl -sS "https://download.geonames.org/export/dump/admin1CodesASCII.txt" >> $DATA_DIR/admin1-codes.csv

echo "  - Processing admin2 codes..."
cp $CONFIG_DIR/headers-admin2-codes.csv $DATA_DIR/admin2-codes.csv
curl -sS "https://download.geonames.org/export/dump/admin2Codes.txt" >> $DATA_DIR/admin2-codes.csv

echo "  - Processing hierarchy data..."
cp "$CONFIG_DIR/headers-hierarchy.csv" "$DATA_DIR/hierarchy.csv"
curl -sS "https://download.geonames.org/export/dump/hierarchy.zip" -o hierarchy.zip
unzip -o hierarchy.zip hierarchy.txt
cat hierarchy.txt >> "$DATA_DIR/hierarchy.csv"
rm hierarchy.zip hierarchy.txt

echo "  - Processing postal code data for Germany..."
cp "$CONFIG_DIR/headers-PostalCode.csv" "$DATA_DIR/postal-codes-DE.csv"
curl -sS "https://download.geonames.org/export/zip/DE.zip" -o postal-codes-DE.zip
unzip -o postal-codes-DE.zip DE.txt
cat DE.txt >> "$DATA_DIR/postal-codes-DE.csv"
rm postal-codes-DE.zip DE.txt

# Create admin3 and admin4 codes from geonames data
# These are identified by specific feature classes and codes:
# - Admin3: feature class (col 7) = "A", feature code (col 8) = "ADM3"
# - Admin4: feature class (col 7) = "A", feature code (col 8) = "ADM4"
echo "Generating admin3 and admin4 codes..."
awk -F'\t' '($7=="A" && $8=="ADM3") {print $9 "." $11 "." $12 "." $13 "\t" $2 "\t" $3 "\t" $1}' $DATA_DIR/geonamesplus.csv > $DATA_DIR/admin3-codes.txt
awk -F'\t' '($7=="A" && $8=="ADM4") {print $9 "." $11 "." $12 "." $13 "." $14 "\t" $2 "\t" $3 "\t" $1}' $DATA_DIR/geonamesplus.csv > $DATA_DIR/admin4-codes.txt

echo "Adding headers to admin3/admin4 files..."
printf "admin3code\tname\tasciiname\tgeonameId\n" | cat - $DATA_DIR/admin3-codes.txt > $DATA_DIR/admin3-codes.csv
printf "admin4code\tname\tasciiname\tgeonameId\n" | cat - $DATA_DIR/admin4-codes.txt > $DATA_DIR/admin4-codes.csv

# Extract country information (feature class "A" and code "PCLI")
echo "Extracting country information..."
awk -F'\t' '($7=="A" && $8=="PCLI"){print $1 "\t" $9 "\t" $2}' $DATA_DIR/geonamesplus.csv > $DATA_DIR/country-codes.txt
printf "countryId\tcountryCode\tname\n" | cat - $DATA_DIR/country-codes.txt > $DATA_DIR/country-codes.csv
rm $DATA_DIR/country-codes.txt

echo "Geonames data processing complete!"