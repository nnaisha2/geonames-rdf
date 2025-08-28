# GeoNames RDF

This repository contains shell scripts that download [GeoNames data dumps](https://download.geonames.org/export/dump/)
and convert them to RDF using [SPARQL Anything](https://github.com/SPARQL-Anything/sparql.anything),
resulting in a `geonames_COUNTRYCODE.ttl` file that you can load into a SPARQL server.

You can download a periodically updated RDF file from http://geonames.ams3.digitaloceanspaces.com/geonames.zip (420 MB).

## Table of Contents

* [Prerequisites](#prerequisites)
* [Usage](#usage)
* [Docker Compose Pipeline](#docker-compose-pipeline)
* [Output](#output)
* [Uploading to GraphDB or qEndpoint](#uploading-to-graphdb-or-qendpoint)
* [Accessing the Web Interface](#accessing-the-web-interface)
* [Estimated Timings](#estimated-timings)

---

## Prerequisites

* **Java 17+** is required for SPARQL Anything
* Docker and Docker Compose installed for containerized usage.
* Optional: A SPARQL endpoint such as GraphDB or qEndpoint.

If you encounter memory issues, increase Java heap size by setting the `JAVA_TOOL_OPTIONS` environment variable, for example:

```bash
-e JAVA_TOOL_OPTIONS="-Xmx8g"
```



## Usage

The pipeline supports running country-specific or full-dataset transformations.

* `COUNTRY_CODE`: 2-letter ISO country code (e.g., `DE`, `FR`) or `allCountries` for the entire dataset.

* `UPLOAD_TARGET`: Upload destination, either `qendpoint` (default) or `graphdb`.


## Docker Compose Pipeline

The entire pipeline is managed via `run.sh` and Docker Compose:

```bash
./run.sh [COUNTRY_CODE] [UPLOAD_TARGET]
```

Defaults:

* `COUNTRY_CODE=DE`
* `UPLOAD_TARGET=qendpoint`

### What `run.sh` does:

1. Downloads GeoNames data for the specified country.
2. Converts the data to RDF Turtle format.
3. Cleans up old outputs, versions the new output with the current date, and generates a web index page.
4. Starts the web server container serving the SPARQL web interface and dataset files.
5. Optionally starts an NGINX proxy (unless `--no-proxy` flag is used).
6. Uploads the RDF data to the specified SPARQL endpoint (`qendpoint` or `graphdb`).

Example to run for France and upload to GraphDB:

```bash
./run.sh FR endpoint
```

To skip starting the NGINX proxy:

```bash
./run.sh FR qendpoint --no-proxy
```

## Output

After processing, RDF Turtle files are saved under the `output/` directory, named:

```
geonames_COUNTRYCODE.ttl
```

## Uploading to GraphDB or qEndpoint

* **qEndpoint:** Runs on `localhost:7300` by default.
* **GraphDB:** Typically available at `localhost:7200`.

## Accessing the Web Interface

After running the pipeline, a web UI is available to explore the data and run SPARQL queries.

Access it locally at:

```
http://localhost/
```
The UI serves the latest RDF output and provides a SPARQL query interface via the backend endpoint.

## Estimated Timings
- RDF upload (Germany): ~4 minutes  
- Full pipeline (Germany): ~10 minutes