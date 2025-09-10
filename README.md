# GeoNames RDF

This repository provides a complete pipeline to transform [GeoNames data dumps](https://download.geonames.org/export/dump/) into RDF Turtle (`.ttl`) format using [SPARQL Anything](https://github.com/SPARQL-Anything/sparql.anything). The output can be uploaded to a SPARQL endpoint and browsed via a simple web interface.



## Table of Contents

* [Overview](#overview)
* [Prerequisites](#prerequisites)
* [Installing Docker and Docker Compose](#installing-docker-and-docker-compose)
* [Usage](#usage)
* [Docker Compose Pipeline](#docker-compose-pipeline)
* [Output](#output)
* [Accessing the Web Interface](#accessing-the-web-interface)
* [Estimated Timings](#estimated-timings)

## Overview

This project automates the following:

1. **Downloads** GeoNames data for a country or the full dataset.
2. **Converts** it to RDF Turtle format using SPARQL Anything.
3. **Generates** a browsable web interface and optionally:
4. **Uploads** the result to a local SPARQL endpoint such as GraphDB or qEndpoint.


## Prerequisites

To use this pipeline, you need:

* **Java 17+** (only if not using Docker)
* **Docker & Docker Compose**
  Docker is required for containerized operation. Follow the [Installation section](#installing-docker-and-docker-compose) if it's not already set up.

> *Docker Compose is used via the `docker compose` command, which requires the Docker Compose plugin.*

To run Docker without `sudo`, add your user to the `docker` group:

```bash
sudo usermod -aG docker $USER
```

If Java runs out of memory during processing, you can increase heap size by setting:

```bash
-e JAVA_TOOL_OPTIONS="-Xmx8g"
```



## Installing Docker and Docker Compose

### On Linux (Ubuntu/Debian)

```bash
# Update system and install dependencies
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker’s official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker and Docker Compose plugin
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

Verify the installation:

```bash
docker --version
docker compose version
```

### On macOS

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. It includes Docker Engine and the Compose plugin.

### On Windows

1. Install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
2. Ensure **WSL2 backend** is enabled during setup.
3. Docker Compose is included.



## Usage

You can run the pipeline for:

* A **specific country** (using its 2-letter ISO code, e.g., `DE`, `FR`)
* The **full dataset** (`allCountries`)

You may also choose where to **upload** the data:

* `qendpoint` (default)
* `graphdb`



## Docker Compose Pipeline

The main entry point is the `run.sh` script:

```bash
./run.sh [COUNTRY_CODE] [UPLOAD_TARGET] [--no-proxy]
```

### Parameters

* `COUNTRY_CODE`: 2-letter ISO code or `allCountries` (default: `DE`)
* `UPLOAD_TARGET`: `qendpoint` (default) or `graphdb`
* `--no-proxy`: optional flag to skip launching the NGINX proxy

### Example commands

Run for France and upload to GraphDB:

```bash
./run.sh FR graphdb
```

Run without NGINX:

```bash
./run.sh FR qendpoint --no-proxy
```



## Output

The RDF Turtle output will be saved in the `output/` directory:

```
output/
└── geonames_COUNTRYCODE.ttl
```

These are ready for loading into a SPARQL database.



## Accessing the Web Interface

Once the pipeline runs, a web interface becomes available:

```
http://localhost/
```

From there, you can:

* Browse generated RDF files
* Run SPARQL queries
* Inspect individual records



## Estimated Timings

Approximate processing durations (may vary by machine):

| Step                | Germany Example |
| ------------------- | --------------- |
| RDF Conversion      | \~4 minutes     |
| Full Pipeline Total | \~10 minutes    |