# GeoNames RDF

This repository contains shell scripts that download [GeoNames data dumps](https://download.geonames.org/export/dump/)
and convert them to RDF using [SPARQL Anything](https://github.com/SPARQL-Anything/sparql.anything),
resulting in a `geonames_COUNTRYCODE.ttl` file that you can load into a SPARQL server.

You can download a periodically updated RDF file from http://geonames.ams3.digitaloceanspaces.com/geonames.zip (420 MB).

---

## Prerequisites

- **Java 17 or higher** is required to run SPARQL Anything.  
  Check your version with:

  ```
  java -version
  ```

- **GraphDB** (or another compatible SPARQL server) is required for loading and querying the resulting RDF.

**Optional:**  
If you encounter memory issues, increase the Java heap size by adding the `-Xmx` flag, e.g.:

```
java -Xmx8g -jar $BIN_DIR/$SPARQL_ANYTHING_JAR --query "$CONFIG_DIR/alternateNames.rq" --output $DATA_DIR/alternate-names.ttl
```

---

## Running

You can run the transform process in a Docker container or directly on your host machine.

### Specifying a Country Code

All scripts accept an optional country code as their first argument.  
- For example, to process Germany: `DE`
- For France: `FR`
- For all countries: `allCountries`

If no country code is specified, the default is `DE`.

**Examples:**

```
./entrypoint.sh DE          # Germany
./entrypoint.sh FR          # France
./entrypoint.sh allCountries # All countries
```

### Note on Processing allCountries

**Processing allCountries requires much more memory.**  
Before running `./entrypoint.sh allCountries` (or `./map.sh allCountries`), increase the Java heap size for SPARQL Anything.

**Example:**  
Edit your `map.sh` so that Java is invoked like this:

```
java -Xmx16g -jar "$BIN_DIR/$SPARQL_ANYTHING_JAR" ...
```

Or, set the `JAVA_TOOL_OPTIONS` environment variable:

```
export JAVA_TOOL_OPTIONS="-Xmx16g"
./entrypoint.sh allCountries
```

---

### In Docker

To run the transform process in a Docker container, run:

```
docker run -v $(pwd)/output:/output --rm ghcr.io/netwerk-digitaal-erfgoed/geonames-rdf
```

For large datasets or `allCountries`, increase Java heap size (recommended):

```shell
docker run -v $(pwd)/output:/output -e JAVA_TOOL_OPTIONS="-Xmx8g" --rm ghcr.io/netwerk-digitaal-erfgoed/geonames-rdf
```

### Directly

To run the scripts directly, run:

```
./download.sh DE
./map.sh DE
./upload_to_graphdb.sh DE
```

Replace `DE` with your desired country code, or use `allCountries` for the full dataset.

This will download SPARQL Anything if not already available.

---

## Output

After running the transform process, you’ll find an `output/geonames_COUNTRYCODE.ttl` file 
that you can load into a SPARQL server. For example: `output/geonames_DE.ttl` for Germany.

## Loading into GraphDB

### **Automated Loading**

Just run:

```
./entrypoint.sh DE
```

Replace `DE` with your desired country code.

This script will:

1. Download and transform the GeoNames data.
2. Upload the resulting RDF file to GraphDB (deleting any existing repository, creating a new one, uploading the RDF, and configuring plugins).

---

### **Manual Upload**

If you want to upload the data separately, you can run:

```
./upload_to_graphdb.sh DE
```

Replace `DE` with your desired country code.