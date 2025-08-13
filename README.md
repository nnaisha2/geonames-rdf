# GeoNames RDF

This repository contains shell scripts that download [GeoNames data dumps](https://download.geonames.org/export/dump/)
and convert them to RDF using [SPARQL Anything](https://github.com/SPARQL-Anything/sparql.anything),
resulting in a `geonames_COUNTRYCODE.ttl` file that you can load into a SPARQL server.

You can download a periodically updated RDF file from http://geonames.ams3.digitaloceanspaces.com/geonames.zip (420 MB).

## Table of Contents

- [Prerequisites](#prerequisites)  
- [Running the Conversion](#running-the-conversion)  
- [Docker Compose Pipeline (3-stage)](#docker-compose-pipeline-3-stage)  
- [Running All with `entrypoint.sh`](#running-all-with-entrypointsh)  
- [Running All with `run-all.sh`](#running-all-with-run-allsh)  
- [Accessing the Web Interface](#accessing-the-web-interface)  
- [Output](#output)  
- [Uploading to GraphDB or qEndpoint](#uploading-to-graphdb-or-qendpoint)  
- [Estimated Timings](#estimated-timings)  

## Prerequisites

- **Java 17+** is required for SPARQL Anything. Check with:
  ```
  java -version
  ```
- A SPARQL endpoint like GraphDB or qEndpoint for RDF upload (optional).
If you encounter memory issues, increase Java heap size, for example:

```bash
java -Xmx8g -jar $BIN_DIR/$SPARQL_ANYTHING_JAR --query "$CONFIG_DIR/alternateNames.rq" --output $DATA_DIR/alternate-names.ttl
```

## Running the Conversion

You can run the process in three ways:

- **Directly on your host**
- **As a single Docker container**
- **With modular Docker Compose (recommended for large datasets or crash recovery)**


### Specify a Country Code

Provide a 2-letter ISO country code as an argument to target that country, e.g.:

```bash
./entrypoint-download.sh DE         # Download GeoNames data for Germany
./entrypoint-transform.sh DE        # Transform data for Germany
./entrypoint-upload.sh DE           # Upload data for Germany
```

Use `allCountries` to process the full dataset (requires >16GB RAM).

### Using Docker (Single Container)

Build the container:
```bash
docker build -t geonames-rdf .
```
Run the container with mounted volumes:

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

## Docker Compose Pipeline (3-stage)

Use Docker Compose to split the process into *download*, *transform*, and *upload* steps. This allows resuming failed runs without repeating previous stages.

Run each step sequentially:

1. Download GeoNames data:

```bash
docker compose -f docker-compose.download.yml up --build
```

2. Transform to RDF:

```bash
docker compose -f docker-compose.transform.yml up --build
```

3. Upload the RDF:

Upload to qEndpoint (default):

```bash
docker compose -f docker-compose.upload.yml up --build
```

Or upload to GraphDB instead:

```bash
docker compose -f docker-compose.upload.graphdb.yml up --build
```

## Running All with `entrypoint.sh`

Run all stages sequentially on your machine by calling the combined entrypoint script:

Example:

```bash
./entrypoint.sh FR
```
This runs download, transform, and upload steps in one command.

## Running All with `run-all.sh`

The `run-all.sh` script automates the entire pipeline end to end using Docker Compose. It accepts two optional arguments: country code and upload target.

Usage:

```bash
./run-all.sh [COUNTRY_CODE] [UPLOAD_TARGET]
```

- `COUNTRY_CODE`: ISO 2-letter country code (defaults to `DE`)
- `UPLOAD_TARGET`: Either `qendpoint` (default) or `graphdb`

## Accessing the Web Interface

After running the pipeline (using `./run-all.sh`), you can access the GeoNames SPARQL Query Interface webpage to query the dataset and download the latest RDF file.

### 1. Start a local web server

The web interface files are in the `web/` directory.  
You need to serve this directory over HTTP so the browser can fetch `latest.json` and dataset files.

From the **root** of this repository, run:
```bash
python3 -m http.server 3000
```

This will serve the repository files at:
```bash
http://localhost:3000/
```

### 2. Open the query interface

Go to:
```bash
http://localhost:3000/web/index.html
```

You will see the GeoNames SPARQL interface where you can:
- Run example or custom SPARQL queries
- Download the latest Turtle RDF file via the **Download RDF Dataset** button (top of the page)

---

**Shortcut (after pipeline completes):**
```bash
./run-all.sh DE
python3 -m http.server 3000
# Then open: http://localhost:3000/web/index.html
```
## Output

After conversion, RDF files are saved in the `output` folder, named:
```
output/geonames_COUNTRYCODE.ttl
```

## Uploading to GraphDB or qEndpoint

Upload to qEndpoint (default):

```bash
UPLOAD_QENDPOINT=true ./entrypoint-upload.sh DE
```

Or using Docker Compose:

```bash
docker compose -f docker-compose.upload.yml up --build
```

Make sure the qEndpoint container is running and accessible on its configured port.

Upload to GraphDB:

```bash
UPLOAD_GRAPHDB=true ./entrypoint-upload.sh DE
```

Or with Docker Compose:

```bash
docker compose -f docker-compose.upload.graphdb.yml up --build
```
GraphDB is typically available at [http://localhost:7200](http://localhost:7200/).

## Estimated Timings
- RDF upload (Germany): ~4 minutes  
- Full pipeline (Germany): ~10 minutes