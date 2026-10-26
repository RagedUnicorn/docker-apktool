############################################
# Download + verify stage
############################################
FROM alpine:3.24.3 AS build

# renovate: datasource=github-releases depName=iBotPeaches/Apktool
ARG APKTOOL_VERSION=3.0.3
# Upstream publishes no checksums for its release assets, so this SHA-256 is
# self-pinned: computed from the downloaded jar and updated by hand whenever
# APKTOOL_VERSION changes. Renovate bumps only the version ARG above; the
# build then fails checksum verification until this hash is refreshed.
# See DEVELOPMENT.md ("Updating Apktool") for the procedure.
ARG APKTOOL_SHA256=eee4669a704a14e0623407e6701b0b91887e61e1e4049cb7a82833e14ae8b5fd

# Build stage labels
LABEL org.opencontainers.image.authors="Michael Wiesendanger <michael.wiesendanger@gmail.com>" \
      org.opencontainers.image.source="https://github.com/ragedunicorn/docker-apktool" \
      org.opencontainers.image.licenses="MIT"

# Tools needed to download the release (verification uses busybox sha256sum)
RUN apk add --no-cache --update curl

WORKDIR /tmp/build

# Download the Apktool release jar and verify it against the pinned SHA-256
RUN set -eux; \
    curl -fsSLO "https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VERSION}/apktool_${APKTOOL_VERSION}.jar"; \
    echo "${APKTOOL_SHA256}  apktool_${APKTOOL_VERSION}.jar" | sha256sum -c -; \
    mkdir -p /out; \
    mv "apktool_${APKTOOL_VERSION}.jar" /out/apktool.jar

############################################
# Runtime stage
############################################
FROM alpine:3.24.3

# renovate: datasource=custom.adoptium-apk depName=temurin-21-jre versioning=loose
ARG TEMURIN_VERSION=21.0.13_p9-r0
ARG BUILD_DATE
ARG VERSION

# OCI-compliant labels
LABEL org.opencontainers.image.title="Apktool on Alpine Linux" \
      org.opencontainers.image.description="Lightweight Apktool Docker image for decoding and rebuilding Android APKs built on Alpine Linux" \
      org.opencontainers.image.vendor="ragedunicorn" \
      org.opencontainers.image.authors="Michael Wiesendanger <michael.wiesendanger@gmail.com>" \
      org.opencontainers.image.source="https://github.com/ragedunicorn/docker-apktool" \
      org.opencontainers.image.documentation="https://github.com/ragedunicorn/docker-apktool/blob/master/README.md" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="docker.io/library/alpine:3.24.3"

# ca-certificates: TLS trust store (family convention; java-cacerts wires the
# JVM keystore against it). The Adoptium repository key must be stored under
# the exact filename referenced by the repository's APKINDEX signature:
# adoptium.rsa.pub. busybox wget ships in the base image and can fetch it.
RUN apk add --no-cache ca-certificates && \
    wget -q -O /etc/apk/keys/adoptium.rsa.pub \
      https://packages.adoptium.net/artifactory/api/security/keypair/public/repositories/apk && \
    echo "https://packages.adoptium.net/artifactory/apk/alpine/main" >> /etc/apk/repositories

# temurin-21-jre: Java runtime for the Apktool jar (java-common, pulled in as
# a dependency, symlinks the JVM binaries into /usr/bin).
# gcompat: glibc compatibility shim for the glibc-linked x86_64 aapt2 binary
# bundled inside apktool.jar, which `apktool b` extracts and executes at
# runtime. On arm64 `apktool b` is unsupported regardless (upstream bundles no
# arm64 aapt2); decoding works on both architectures.
RUN apk add --no-cache \
    temurin-21-jre=${TEMURIN_VERSION} \
    gcompat

ENV JAVA_HOME=/usr/lib/jvm/java-21-temurin-jre \
    PATH=/usr/lib/jvm/java-21-temurin-jre/bin:$PATH \
    LANG=C.UTF-8

# Non-root user with a real home: Apktool requires a writable framework
# directory under $HOME/.local/share/apktool/framework — even `apktool d`
# extracts the bundled framework there and aborts if the directory cannot be
# created. Pre-create it so a named volume mounted there inherits apktool's
# ownership instead of being created root-owned and unwritable.
RUN adduser -D -h /home/apktool -s /sbin/nologin apktool && \
    mkdir -p /home/apktool/.local/share/apktool/framework && \
    chown -R apktool:apktool /home/apktool

COPY --from=build --chmod=644 /out/apktool.jar /usr/local/bin/apktool.jar
COPY --chmod=755 scripts/apktool /usr/local/bin/apktool

# Create working directory for input/output files
WORKDIR /workspace

RUN chown -R apktool:apktool /workspace

USER apktool

# Apktool is the entrypoint; pass subcommands (d, b, if, ...) as `docker run` args
ENTRYPOINT ["apktool"]

# Default to printing the version if no arguments are provided
CMD ["--version"]
