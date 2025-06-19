# GeoNames RDF

This repository contains shell scripts that download [GeoNames data dumps](https://download.geonames.org/export/dump/)
and convert them to RDF using [SPARQL Anything](https://github.com/SPARQL-Anything/sparql.anything),
resulting in a `geonames.ttl` file that you can load into a SPARQL server.

You can download a periodically updated RDF file from http://geonames.ams3.digitaloceanspaces.com/geonames.zip (420 MB).

---

## Prerequisites

- **Java 17 or higher** is required to run SPARQL Anything.  
  Check your version with:

  ```bash
  java -version

- **GraphDB** (or another compatible SPARQL server) is required for loading and querying the resulting RDF.

**Optional:**  
If you encounter memory issues, increase the Java heap size by adding the `-Xmx` flag, e.g.:


 ```bash
java -Xmx8g -jar $BIN_DIR/$SPARQL_ANYTHING_JAR --query "$CONFIG_DIR/alternateNames.rq" --output $DATA_DIR/alternate-names.ttl
``` 
---

## Running

You can run the transform process in a Docker container or directly on your host machine.

### In Docker

To run the transform process in a Docker container, run:

```shell
docker run -v $(pwd)/output:/output --rm ghcr.io/netwerk-digitaal-erfgoed/geonames-rdf
```

For large datasets, increase Java heap size (recommended):

```shell
docker run -v $(pwd)/output:/output -e JAVA_TOOL_OPTIONS="-Xmx8g" --rm ghcr.io/netwerk-digitaal-erfgoed/geonames-rdf
```

### Directly

To run the scripts directly, run:

```shell
./download.sh
```

Then start the mapping process with:

```shell
./map.sh
```

This will download SPARQL Anything if not already available.


---

## Output

After running the transform process, you’ll find a `output/geonames.ttl` file 
that you can load into a SPARQL server. 

## Loading into GraphDB

### Automated Loading with `entrypoint.sh`

To automate repository creation, data loading, and plugin configuration in GraphDB, use:


```shell
./entrypoint.sh
```
