# GeoNames RDF

This repository contains shell scripts that download [GeoNames data dumps](https://download.geonames.org/export/dump/)
and convert them to RDF using [SPARQL Anything](https://github.com/SPARQL-Anything/sparql.anything),
resulting in a `geonames.ttl` file that you can load into a SPARQL server.

You can download a periodically updated RDF file from http://geonames.ams3.digitaloceanspaces.com/geonames.zip (420 MB).

## Prerequisites

- **Java 17 or higher** is required to run SPARQL-Anything.  
  Please ensure Java 17+ is installed and available in your `PATH` before using the `map.sh` script.  
  You can check your version with:

  ```bash
  java -version


Optional: 
- Increase Java Heap Size
If you encounter memory issues, you may need to increase the Java heap size manually.
You can do this by running SPARQL-Anything with the -Xmx flag, for example:

 ```bash
java -Xmx8g -jar $BIN_DIR/$SPARQL_ANYTHING_JAR --query "$CONFIG_DIR/alternateNames.rq" --output $DATA_DIR/alternate-names.ttl
``` 


## Running

You can run the transform process in a Docker container or directly on your host machine.

### In Docker

To run the transform process in a Docker container, run:

```shell
docker run -v $(pwd)/output:/output --rm ghcr.io/netwerk-digitaal-erfgoed/geonames-rdf
```
With increased Java heap size (recommended for large datasets)
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

## Output

After running the transform process, you’ll find a `output/geonames.ttl` file 
that you can load into a SPARQL server. 
