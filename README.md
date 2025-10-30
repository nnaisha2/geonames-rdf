# GeoNames RDF

This repository provides a complete pipeline to transform [GeoNames data dumps](https://download.geonames.org/export/dump/) into RDF Turtle (`.ttl`) format using [SPARQL Anything](https://github.com/SPARQL-Anything/sparql.anything). The output can be uploaded to a SPARQL endpoint and browsed via a simple web interface. You can find a running example of both for Germany at [https://geonames.need.energy](https://geonames.need.energy).

## Table of Contents

* [Prerequisites](#prerequisites)
* [Usage](#usage)
* [Docker Compose Pipeline](#docker-compose-pipeline)
* [Output](#output)
* [Accessing the Web Interface](#accessing-the-web-interface)
* [Estimated Timings](#estimated-timings)

## Prerequisites

To run this pipeline, you need:

* **Java 17+**: Only required if Docker is not used
* **Docker**: Install it following the [official Docker Engine installation guide](https://docs.docker.com/engine/install)  
* **Docker Compose**: See the [Docker Compose installation instructions](https://docs.docker.com/compose/install)  

> Note: The provided scripts run Docker commands without using `sudo`.

## Usage

You can run the pipeline for:

* A **specific country** (using its 2-letter ISO code, e.g., `DE`, `FR`)
* The **full dataset** (`allCountries`)

You may also choose where to **upload** the data:

* `qendpoint`
* `graphdb`

You can also specify a **remote SPARQL endpoint URL**. This URL would be used by the HTML web interface and the SPARQL query UI to know which endpoint to query.    


## Docker Compose Pipeline

Run the `run.sh` script to start the Docker Compose services that download, transform, and upload the GeoNames data.

Run it as:

```bash
./run.sh [COUNTRY_CODE] [DEPLOYED_TRIPLESTORE] [ENDPOINT_BASE_URL] [--no-proxy]
```

### Parameters

* `COUNTRY_CODE`: 2-letter ISO code or `allCountries` (default: `DE`)
* `DEPLOYED_TRIPLESTORE`: `qendpoint` (default) or `graphdb`
* `ENDPOINT_BASE_URL`: optional custom SPARQL endpoint (default: `http://localhost/sparql`). The `nginx.conf` file expects the endpoint path `/sparql`; update it if your SPARQL service uses another path.
* `--no-proxy`: optional flag to skip launching the NGINX proxy

### Example commands

Run for Germany and upload to GraphDB:

```bash
./run.sh DE graphdb
```

Run with a custom SPARQL endpoint:

```
./run.sh DE qendpoint https://my-sparql-endpoint.org/sparql
```

Run without NGINX:

```bash
./run.sh DE qendpoint --no-proxy
```

## Output

The RDF Turtle output will be saved in the `output/` directory:

```
output/
└── geonames_COUNTRYCODE.ttl
```

This file can be imported into a SPARQL endpoint.

## Accessing the Web Interface

Once the pipeline runs, a web interface becomes available at:

```
http://localhost/
```

From there, you can:

* Download the generated RDF dataset as a ZIP file
* Write and run SPARQL queries against the configured endpoint
* View specific entries by querying the dataset
* Access the documentation page

## Estimated Timings

| Step                | Country code = DE |
| ------------------- | --------------- |
| RDF Conversion      | ~6 minutes      |
| RDF Merge           | ~3 minutes      |
| RDF upload          | ~5 minutes      |
| Full Pipeline Total | ~14 minutes     |