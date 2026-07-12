# Apktool Alpine Docker Image

A lightweight [Apktool](https://apktool.org/) installation on Alpine Linux with an Eclipse Temurin 21 JRE, for
decoding and rebuilding Android APKs.

## Quick Start

```bash
# Pull latest version
docker pull ragedunicorn/apktool:latest

# Or pull specific version
docker pull ragedunicorn/apktool:3.0.2-alpine3.24.1-1

# Decode an APK
docker run -v $(pwd):/workspace ragedunicorn/apktool:latest d app.apk -o app
```

## Features

- 🚀 **Small footprint**: Alpine Linux base with a JRE-only Temurin 21 runtime
- 🔐 **Verified artifact**: Apktool jar pinned by version and SHA-256 checksum at build time
- 🛠️ **Complete tooling**: gcompat glibc shim included so Apktool's bundled aapt2 works for rebuilds (amd64)
- 🔒 **Non-root**: Runs as the unprivileged `apktool` user by default
- 🏗️ **Multi-platform**: linux/amd64 (decode + rebuild) and linux/arm64 (decode only — upstream ships no arm64 aapt2)

## Usage Examples

### Decode an APK

```bash
docker run -v $(pwd):/workspace ragedunicorn/apktool:latest \
  d app.apk -o app
```

### Decode resources only (skip disassembling code)

```bash
docker run -v $(pwd):/workspace ragedunicorn/apktool:latest \
  d -s app.apk -o app
```

### Rebuild a decoded project

```bash
docker run -v $(pwd):/workspace ragedunicorn/apktool:latest \
  b app -o app-rebuilt.apk
```

The rebuilt APK is unsigned — sign it with apksigner or a similar tool before installing it on a device.

### Raise the JVM heap for large APKs

```bash
docker run -e APKTOOL_JAVA_OPTS="-Xmx4G -Dfile.encoding=utf-8" \
  -v $(pwd):/workspace ragedunicorn/apktool:latest d big-app.apk -o big-app
```

## Tags

This image uses semantic versioning that includes all component versions:

**Format:** `{apktool_version}-alpine{alpine_version}-{build_number}`

### Version Examples

- `3.0.2-alpine3.24.1-1` - Initial release with Apktool 3.0.2 and Alpine 3.24.1
- `3.0.2-alpine3.24.1-2` - Rebuild of same versions (bug fixes, security patches)
- `3.0.2-alpine3.24.2-1` - Alpine Linux patch update
- `3.0.3-alpine3.24.1-1` - Apktool version update

When updates are available through automated dependency management, new releases are created with appropriate version tags.

## Links

- **GitHub**: [https://github.com/RagedUnicorn/docker-apktool](https://github.com/RagedUnicorn/docker-apktool)
- **Issues**: [https://github.com/RagedUnicorn/docker-apktool/issues](https://github.com/RagedUnicorn/docker-apktool/issues)
- **Releases**: [https://github.com/RagedUnicorn/docker-apktool/releases](https://github.com/RagedUnicorn/docker-apktool/releases)
- **Apktool**: [https://github.com/iBotPeaches/Apktool](https://github.com/iBotPeaches/Apktool)

## License

MIT License - See [GitHub repository](https://github.com/RagedUnicorn/docker-apktool) for details. Apktool itself is
licensed under the Apache License 2.0.
