# =============================================================================
# carts on a glibc JRE so the current Dynatrace OneAgent can inject it.
# -----------------------------------------------------------------------------
# The prebuilt carts images (wmsegar/carts:*, dynatracesockshop/carts:*) are all
# built on an ancient Alpine/musl base. The current OneAgent's musl Java module
# needs the `getentropy` symbol, which that old musl doesn't export, so the JVM
# aborts at init ("liboneagentjava.so ... getentropy: symbol not found") and
# carts crash-loops without ever reporting service metrics.
#
# Fix: take the *exact same Spring Boot fat-jar* out of the original image and
# run it on a modern glibc JRE (Ubuntu-based Temurin 8). Same app, same
# endpoints, same carts-db wiring, port 8080 - but now OneAgent injects the
# glibc module and carts is fully monitored (quality gate gets real data).
#
# Build:  docker build -t dtacm/carts:1.0 carts-glibc      (or: make carts-image)
# =============================================================================

# ---- stage 1: pull the app jar out of the original (alpine/musl) image -------
FROM dynatracesockshop/carts:0.5.0 AS src
# Locate the Spring Boot fat-jar wherever it lives and stage it at a known path.
# (Build output prints every candidate so you can verify the right one was taken.)
RUN set -e; \
    echo "jar candidates:"; \
    find / -maxdepth 6 -name '*.jar' 2>/dev/null || true; \
    jar="$(find / -maxdepth 6 -name '*.jar' \( -name 'app.jar' -o -name 'carts*.jar' -o -path '*/app*.jar' \) 2>/dev/null | head -1)"; \
    if [ -z "$jar" ]; then jar="$(find / -maxdepth 6 -name '*.jar' 2>/dev/null | head -1)"; fi; \
    echo "using jar: $jar"; \
    cp "$jar" /tmp/carts.jar

# ---- stage 2: run it on glibc -----------------------------------------------
FROM eclipse-temurin:8-jre
WORKDIR /app
COPY --from=src /tmp/carts.jar /app/carts.jar
# Same JVM flags the k8s manifest used (PermSize flags dropped - gone in Java 8+).
ENV JAVA_OPTS="-Xms128m -Xmx512m -XX:+UseG1GC -Djava.security.egd=file:/dev/urandom"
EXPOSE 8080
# Force server.port=8080 so the nginx gateway's carts-internal:8080 target holds.
ENTRYPOINT ["sh","-c","exec java $JAVA_OPTS -jar /app/carts.jar --server.port=8080"]
