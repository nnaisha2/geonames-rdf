# GeoNames RDF

This repository contains shell scripts that download [GeoNames data dumps](https://download.geonames.org/export/dump/)
and convert them to RDF using [SPARQL Anything](https://github.com/SPARQL-Anything/sparql.anything),
resulting in a `geonames_COUNTRYCODE.ttl` file that you can load into a SPARQL server.

You can download a periodically updated RDF file from http://geonames.ams3.digitaloceanspaces.com/geonames.zip (420 MB).

## Table of Contents

- [Prerequisites](#prerequisites)  
- [Running the Conversion](#running-the-conversion)  
- [Output](#output)  
- [Loading into GraphDB](#loading-into-graphdb)  

## Prerequisites

- **Java 17+** is required for SPARQL Anything. Check with:
  ```
  java -version
  ```
- A SPARQL server like **GraphDB** is needed for loading and querying RDF.

*If you encounter memory issues, increase Java heap size:*
```
java -Xmx8g -jar $BIN_DIR/$SPARQL_ANYTHING_JAR --query "$CONFIG_DIR/alternateNames.rq" --output $DATA_DIR/alternate-names.ttl
```

## Running the Conversion

You can run the scripts via Docker (single or multi-container), or directly on your host.

### Specify a Country Code

Provide a 2-letter ISO country code as an argument to target that country, e.g.:

```
./entrypoint.sh DE         # Germany
./entrypoint.sh FR         # France
./entrypoint.sh allCountries  # Full dataset (requires more memory)
```

If omitted, `DE` (Germany) is the default.

*Note:* Processing `allCountries` requires increased Java heap size (e.g., `-Xmx16g`).

### Using Docker (Single Container)

Build the image:
```bash
docker build -t geonames-rdf .
```

Run the process, for example for France:
```bash
docker run --user "$(id -u):$(id -g)" -it --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/output:/app/output \
  geonames-rdf FR
```

Increase Java heap size if needed by setting environment variable `JAVA_TOOL_OPTIONS`:
```bash
-e JAVA_TOOL_OPTIONS="-Xmx8g"
```

### Using Docker Compose

To run GraphDB and the RDF pipeline together:
```bash
docker compose up --build
```
Access GraphDB at [http://localhost:7200](http://localhost:7200).

### Running on Host

Run these scripts sequentially:
```
./download.sh DE
./map.sh DE
./upload_to_graphdb.sh DE "-u username:password"
```
Replace `DE` with your target country code or `allCountries`. The second argument is optional and used for authentication.

## Output

After conversion, find `output/geonames_COUNTRYCODE.ttl`, e.g., `output/geonames_DE.ttl` for Germany.

## Loading into GraphDB

### Automated Upload
Run:
```
UPLOAD=true ./entrypoint.sh
```
This downloads data, converts to RDF, uploads to GraphDB, creates repositories, and configures plugins.

### Manual Upload
Run separately with:
```
./upload_to_graphdb.sh DE "-u username:password"
```

**Estimated Upload Times:**  
- Approx. 4 minutes to upload Germany dataset RDF (230 seconds).  
- Full process (download, convert, upload) takes about 10 minutes for Germany.