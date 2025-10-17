FROM eclipse-temurin:21-jre
LABEL org.opencontainers.image.source="https://github.com/netwerk-digitaal-erfgoed/geonames-rdf"
ENV SPARQL_ANYTHING_VERSION=v1.0.0
ENV SPARQL_ANYTHING_JAR="sparql-anything-$SPARQL_ANYTHING_VERSION.jar"
ENV OUTPUT_DIR=/output
WORKDIR /app
RUN mkdir bin

RUN apt-get update && apt-get install -y zip raptor2-utils && rm -rf /var/lib/apt/lists/*
# If you see HTTP/2 errors when downloading from GitHub, uncomment and use the alternate command below to force HTTP/1.1 and add retries.
RUN curl -L https://github.com/SPARQL-Anything/sparql.anything/releases/download/$SPARQL_ANYTHING_VERSION/$SPARQL_ANYTHING_JAR -o bin/$SPARQL_ANYTHING_JAR
# RUN curl --http1.1 -L --retry 5 --retry-all-errors https://github.com/SPARQL-Anything/sparql.anything/releases/download/$SPARQL_ANYTHING_VERSION/$SPARQL_ANYTHING_JAR -o bin/$SPARQL_ANYTHING_JAR
COPY . .

RUN chmod +x /app/*.sh
RUN chmod +x /app/scripts/*.sh