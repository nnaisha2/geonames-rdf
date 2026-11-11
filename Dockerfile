FROM eclipse-temurin:25-jre
LABEL org.opencontainers.image.source="https://github.com/netwerk-digitaal-erfgoed/geonames-rdf"
ENV SPARQL_ANYTHING_VERSION=v1.3.0
ENV SPARQL_ANYTHING_JAR="sparql-anything-$SPARQL_ANYTHING_VERSION.jar"
# SHA-256 of the jar above (matches the digest GitHub publishes for the release asset).
# Update it together with SPARQL_ANYTHING_VERSION, and also in scripts/map.sh.
ENV SPARQL_ANYTHING_SHA256=0855bc869a35f83c4a97a5d31ca65e9f4ff16fd9c5a4f619ad7a7bd508053414
ENV OUTPUT_DIR=/output
# The containers run as an unprivileged user without a home directory
ENV HOME=/tmp
WORKDIR /app
RUN mkdir bin

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip zip raptor2-utils && rm -rf /var/lib/apt/lists/*
# If you see HTTP/2 errors when downloading from GitHub, uncomment and use the alternate command below to force HTTP/1.1 and add retries.
RUN curl -fL https://github.com/SPARQL-Anything/sparql.anything/releases/download/$SPARQL_ANYTHING_VERSION/$SPARQL_ANYTHING_JAR -o bin/$SPARQL_ANYTHING_JAR \
 && echo "$SPARQL_ANYTHING_SHA256  bin/$SPARQL_ANYTHING_JAR" | sha256sum -c -
# RUN curl --http1.1 -fL --retry 5 --retry-all-errors https://github.com/SPARQL-Anything/sparql.anything/releases/download/$SPARQL_ANYTHING_VERSION/$SPARQL_ANYTHING_JAR -o bin/$SPARQL_ANYTHING_JAR \
#  && echo "$SPARQL_ANYTHING_SHA256  bin/$SPARQL_ANYTHING_JAR" | sha256sum -c -
COPY . .

RUN chmod +x /app/*.sh
RUN chmod +x /app/scripts/*.sh

# Do not run as root. docker-compose.yml overrides this with the host user's
# UID/GID (written to .env by run.sh) so files in data/ and output/ belong to that user.
USER 1000:1000
