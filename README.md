# GeoNames RDF

This repository provides a complete pipeline to transform [GeoNames data dumps](https://download.geonames.org/export/dump/) into RDF Turtle (`.ttl`) format using [SPARQL Anything](https://github.com/SPARQL-Anything/sparql.anything). The output can be uploaded to a SPARQL endpoint and browsed via a simple web interface. You can find a running example of both for Germany at [https://geonames.need.energy](https://geonames.need.energy).

## Table of Contents

* [Prerequisites](#prerequisites)
* [Usage](#usage)
* [Docker Compose Pipeline](#docker-compose-pipeline)
* [Output](#output)
* [Accessing the Web Interface](#accessing-the-web-interface)
* [Public SPARQL Endpoint](#public-sparql-endpoint)
* [Updating Dependencies](#updating-dependencies)
* [Estimated Timings](#estimated-timings)

## Prerequisites

To run this pipeline, you need:

* **Java 21+**: Only required if Docker is not used (SPARQL Anything v1.3.0 needs Java 21)
* **Docker**: Install it following the [official Docker Engine installation guide](https://docs.docker.com/engine/install)  
* **Docker Compose**: See the [Docker Compose installation instructions](https://docs.docker.com/compose/install)  

> Note: The provided scripts run Docker commands without using `sudo`.
>
> The following host ports must be free: `80` (NGINX proxy), `8080` (web UI) and `7400` (qEndpoint), or `7200` when using GraphDB.

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
* `ENDPOINT_BASE_URL`: optional custom SPARQL endpoint (default: `https://geonames.need.energy/sparql`). The `nginx.conf` file expects the endpoint path `/sparql`; update it if your SPARQL service uses another path.
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

### File ownership

The pipeline containers run as your own user, not as root, so the files in `data/` and `output/` belong to you. `run.sh` stores your user and group ID in `.env` for this.

If an earlier version of the pipeline ran as root, `run.sh` stops with an error about files not owned by you. Fix it once with:

```bash
sudo chown -R $(id -u):$(id -g) data output web
```

## Output

The RDF Turtle output will be saved in the `output/` directory:

```
output/
├── geonames_COUNTRYCODE.ttl                  # the dataset
├── geonames_COUNTRYCODE_YYYY-MM-DD.ttl       # dated copy of the dataset
├── geonames_COUNTRYCODE_YYYY-MM-DD.ttl.zip   # zipped copy, offered for download in the web UI
└── geonames_COUNTRYCODE_merged.ttl           # dataset plus GeoNames ontology (qEndpoint only)
```

`geonames_COUNTRYCODE.ttl` can be imported into any SPARQL endpoint.

## Accessing the Web Interface

Once the pipeline runs, a web interface becomes available at:

```
http://localhost/
```

When run with `--no-proxy`, the web interface is at `http://localhost:8080/`.

From there, you can:

* Download the generated RDF dataset as a ZIP file
* Write and run SPARQL queries against the configured endpoint
* View specific entries by querying the dataset
* Access the documentation page

## Public SPARQL Endpoint

The NGINX proxy exposes qEndpoint read-only at `/sparql`:

* Only queries are forwarded: `GET` with a `query` parameter, or `POST` with `Content-Type: application/sparql-query`. SPARQL updates and form-encoded `POST` requests are rejected with `403`.
* Queries are stopped after 60 seconds.
* Each client may send 5 requests per second (bursts of up to 20) and run 4 queries at the same time; beyond that it gets `429`. These limits are per client IP, so if NGINX runs behind another reverse proxy, configure the real client IP as described in `nginx-proxy/nginx.conf`.

> **Warning:** port `7400` gives direct access to qEndpoint, including its upload and update API, without these restrictions. Do not expose it to untrusted networks.

## Updating Dependencies

Downloads are pinned to exact versions and verified:

* **SPARQL Anything:** when changing `SPARQL_ANYTHING_VERSION`, also update `SPARQL_ANYTHING_SHA256` in the `Dockerfile` and in `scripts/map.sh`.
* **Web libraries:** the CDN files in `web/index.template.html` and `web/docs.html` have `integrity` hashes, so browsers refuse modified files. When changing a version, recompute its hash:

  ```bash
  curl -sL <url> | openssl dgst -sha384 -binary | openssl base64 -A
  ```

  and set `integrity="sha384-<hash>"`.

## Estimated Timings

| Step                | Country code = DE |
| ------------------- | --------------- |
| RDF Conversion      | ~6 minutes      |
| RDF Merge           | ~3 minutes      |
| RDF upload          | ~5 minutes      |
| Full Pipeline Total | ~14 minutes     |