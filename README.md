# docker-apktool

![](./docs/docker_apktool.png)

[![Release Build](https://github.com/RagedUnicorn/docker-apktool/actions/workflows/docker_release.yml/badge.svg)](https://github.com/RagedUnicorn/docker-apktool/actions/workflows/docker_release.yml)
[![Test](https://github.com/RagedUnicorn/docker-apktool/actions/workflows/test.yml/badge.svg)](https://github.com/RagedUnicorn/docker-apktool/actions/workflows/test.yml)
![License: MIT](docs/license_badge.svg)

> Docker Alpine image with Apktool for decoding and rebuilding Android APKs.

![](./docs/alpine_linux_logo.svg)

## Overview

This Docker image provides [Apktool](https://apktool.org/) on Alpine Linux with an Eclipse Temurin 21 JRE. The Apktool
release jar is downloaded from the official GitHub release and verified against a pinned SHA-256 checksum at build
time. Use it to decode APK resources to nearly original form, inspect manifests and smali code, and rebuild modified
apps — without installing Java or Apktool on your host.

## Features

- **Small footprint**: Alpine Linux base with a JRE-only Temurin 21 runtime
- **Verified artifact**: Apktool jar pinned by version and SHA-256 checksum
- **Complete tooling**: `gcompat` glibc shim included so Apktool's bundled aapt2 works for rebuilds (amd64)
- **Non-root**: Runs as the unprivileged `apktool` user by default
- **Volume mounting**: Easy file input/output through `/workspace`

## Quick Start

```bash
# Pull the image
docker pull ragedunicorn/apktool:latest

# Decode an APK in the current directory
docker run -v $(pwd):/workspace ragedunicorn/apktool:latest d app.apk -o app
```

For development and building the image yourself, see [DEVELOPMENT.md](DEVELOPMENT.md).

## Usage

The container uses `apktool` as the entrypoint, so any Apktool subcommand (`d`, `b`, `if`, ...) and its parameters can
be passed directly to the `docker run` command. Running the image without arguments prints the Apktool version.

### Basic Usage

**Linux/macOS:**

```bash
# Using latest version
docker run -v $(pwd):/workspace ragedunicorn/apktool:latest [apktool-options]

# Using specific Apktool version (latest Alpine build)
docker run -v $(pwd):/workspace ragedunicorn/apktool:3.0.2 [apktool-options]

# Using exact version combination
docker run -v $(pwd):/workspace ragedunicorn/apktool:3.0.2-alpine3.24.1-1 [apktool-options]
```

**Windows (PowerShell):**

```powershell
# Using latest version
docker run -v ${PWD}:/workspace ragedunicorn/apktool:latest [apktool-options]

# Using specific Apktool version (latest Alpine build)
docker run -v ${PWD}:/workspace ragedunicorn/apktool:3.0.2 [apktool-options]
```

### Examples

#### Decode an APK

```bash
docker run -v $(pwd):/workspace ragedunicorn/apktool:latest d app.apk -o app
```

```powershell
docker run -v ${PWD}:/workspace ragedunicorn/apktool:latest d app.apk -o app
```

#### Decode Resources Only (skip disassembling code)

```bash
docker run -v $(pwd):/workspace ragedunicorn/apktool:latest d -s app.apk -o app
```

#### Rebuild a Decoded Project

```bash
docker run -v $(pwd):/workspace ragedunicorn/apktool:latest b app -o app-rebuilt.apk
```

The rebuilt APK is unsigned — sign it with apksigner or a similar tool before installing it on a device (signing is
deliberately out of scope for this image).

#### Install a Framework APK

```bash
docker run -v $(pwd):/workspace ragedunicorn/apktool:latest if framework-res.apk -p framework
```

Using `-p`/`--frame-path` keeps the framework files in the mounted workspace so they persist across container runs.
See [Apktool's framework documentation](https://apktool.org/wiki/in-depth/frameworks/) for background.

#### Raise the JVM Heap for Large APKs

```bash
docker run -e APKTOOL_JAVA_OPTS="-Xmx4G -Dfile.encoding=utf-8" \
  -v $(pwd):/workspace ragedunicorn/apktool:latest d big-app.apk -o big-app
```

## Architecture Support

The image is published for `linux/amd64` and `linux/arm64`:

- **amd64**: Full support — decoding (`apktool d`) and rebuilding (`apktool b`)
- **arm64**: Decoding works without restrictions. Rebuilding is **not supported**: Apktool ships only an x86_64 aapt2
  binary inside its jar and provides no fallback to a system aapt2. If you must rebuild on arm64, supply your own
  arm64 aapt2 binary and point Apktool at it with `apktool b --aapt /path/to/aapt2`.

On amd64 the bundled aapt2 is a glibc binary; the image includes the `gcompat` compatibility shim so it runs on
Alpine's musl libc. The decode/rebuild round trip is exercised in CI on every change.

## Docker Compose Usage

This repository includes Docker Compose configurations for easier usage and common APK workflows.

### Basic Setup

1. The repository ships a `workspace` directory with a bundled sample APK:

```
workspace/
├── input/        # place input APKs here (contains the bundled hello.apk sample)
└── output/       # decoded projects and rebuilt APKs end up here
```

2. Place your input APKs in `workspace/input/`

3. Run Apktool using docker compose:

```bash
docker compose run --rm apktool d input/hello.apk -o output/hello
```

### Example Configurations

The `examples/` directory contains specialized docker-compose files for common tasks:

#### Decoding (`examples/docker-compose.decode.yml`)

```bash
# Decode the bundled sample APK
docker compose -f examples/docker-compose.decode.yml run --rm decode-apk

# Decode resources only
docker compose -f examples/docker-compose.decode.yml run --rm decode-no-sources
```

#### Rebuilding (`examples/docker-compose.build.yml`)

```bash
# Rebuild the project decoded by the decode example
docker compose -f examples/docker-compose.build.yml run --rm build-apk
```

#### Framework Files (`examples/docker-compose.framework.yml`)

```bash
# Install a vendor framework into workspace/framework/
docker compose -f examples/docker-compose.framework.yml run --rm install-framework
```

See [examples/README.md](examples/README.md) for the full list of example services.

### Environment Variables

- `APKTOOL_VERSION`: Specify the image version (default: latest)
- `APKTOOL_JAVA_OPTS`: Replace the default JVM flags
  (`-Xmx1024M -Dfile.encoding=utf-8 -Djdk.util.zip.disableZip64ExtraFieldValidation=true -Djdk.nio.zipfs.allowDotZipEntry=true`)

### Tips

1. **Custom Commands**: Any Apktool arguments can be passed directly:

   ```bash
   docker compose run --rm apktool d -f -s input/app.apk -o output/app
   ```

2. **Framework Persistence**: Frameworks installed with `apktool if` land in the container's home directory and are
   lost when the container exits. Either use `-p framework` to keep them in the mounted workspace, or uncomment the
   `apktool-framework` named volume in `docker-compose.yml`.

3. **Persistent Settings**: The repository includes a `.env` file with default settings. You can modify it to set your
   preferred version:

   ```env
   APKTOOL_VERSION=3.0.2-alpine3.24.1-1
   ```

## Versioning

This project uses semantic versioning that matches the Docker image contents:

**Format:** `{apktool_version}-alpine{alpine_version}-{build_number}`

Examples:
- `3.0.2-alpine3.24.1-1` - Apktool 3.0.2 on Alpine 3.24.1, build 1
- `latest` - Most recent stable release

For detailed release process and versioning guidelines, see [RELEASE.md](RELEASE.md).

## Automated Dependency Updates

This project uses [Renovate](https://docs.renovatebot.com/) to automatically check for updates to:
- Alpine Linux base image version (all major, minor, and patch updates)
- Apktool release version (tracked via GitHub releases)
- Eclipse Temurin JRE package version (tracked via the Adoptium apk repository)

Renovate runs weekly (every Monday) and creates pull requests when updates are available. Apktool publishes no
checksums for its release assets, so the pinned `APKTOOL_SHA256` in the Dockerfile must be refreshed manually on
Apktool update pull requests — see [DEVELOPMENT.md](DEVELOPMENT.md) for the procedure.

## Documentation

- [Development Guide](DEVELOPMENT.md) - Building, debugging, and contributing
- [Testing Guide](TEST.md) - Running and writing tests
- [Release Process](RELEASE.md) - Creating releases and versioning

## Links

- [Apktool Website](https://apktool.org/)
- [Apktool on GitHub](https://github.com/iBotPeaches/Apktool)
- [Alpine Linux](https://www.alpinelinux.org/)

# License

The Docker packaging in this repository is licensed under the MIT License. Apktool itself is licensed under the
[Apache License 2.0](https://github.com/iBotPeaches/Apktool/blob/master/LICENSE.md).

MIT License

Copyright (c) 2026 Michael Wiesendanger

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
