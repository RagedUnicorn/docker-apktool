# Apktool Docker Examples

This directory contains docker-compose configurations for common APK reverse engineering tasks.

## Setup

The examples read input files from `workspace/input/` and write results to `workspace/output/` (relative to the
repository root). A sample `workspace/input/hello.apk` ships with the repository, so the `decode-apk` example (and the
`run-examples` run configuration) work out of the box with no setup.

To try the examples with real apps, drop your own APKs into `workspace/input/`:

```bash
# workspace/input/ already exists with the bundled sample; add more APKs as needed
cp my-app.apk workspace/input/my-app.apk
```

The `workspace/` directory is otherwise gitignored — only the bundled sample is tracked, so your own inputs and all
generated outputs stay out of version control.

All commands below are run from the repository root.

## Decoding (`docker-compose.decode.yml`)

| Service             | What it does                                                 |
|---------------------|--------------------------------------------------------------|
| `decode-apk`        | Decode `input/hello.apk` (resources and sources)             |
| `decode-no-sources` | Decode resources only, skip disassembling code (faster)      |

```bash
docker compose -f examples/docker-compose.decode.yml run --rm decode-apk
```

Decode a different APK:

```bash
APK_FILE=my-app.apk docker compose -f examples/docker-compose.decode.yml run --rm decode-apk
```

## Rebuilding (`docker-compose.build.yml`)

| Service     | What it does                                            |
|-------------|---------------------------------------------------------|
| `build-apk` | Rebuild `output/decoded` into `output/rebuilt.apk`      |

```bash
docker compose -f examples/docker-compose.build.yml run --rm build-apk
```

The rebuilt APK is unsigned — sign it with apksigner or a similar tool before installing it on a device. Rebuilding
only works on amd64 hosts (see the Architecture Support section in the main README).

## Framework Files (`docker-compose.framework.yml`)

| Service                 | What it does                                                        |
|-------------------------|---------------------------------------------------------------------|
| `install-framework`     | Install `input/framework-res.apk` into `workspace/framework/`       |
| `decode-with-framework` | Decode an APK against the persistent `workspace/framework/` dir     |

```bash
docker compose -f examples/docker-compose.framework.yml run --rm install-framework
APK_FILE=vendor-app.apk docker compose -f examples/docker-compose.framework.yml run --rm decode-with-framework
```

No framework APK is bundled — vendor frameworks (e.g. `framework-res.apk` pulled from a device) must be supplied by
you. See the [Apktool framework documentation](https://apktool.org/wiki/in-depth/frameworks/) for background.

## Customizing

The services use fixed file names (`input/hello.apk` etc.) to stay copy-paste simple. For ad-hoc commands, use the
main compose file from the repository root and pass any Apktool arguments directly:

```bash
docker compose run --rm apktool d input/my-app.apk -o output/my-app
```

## Image Version

All examples use `ragedunicorn/apktool:${APKTOOL_VERSION:-latest}`. To run them against a different version:

**Linux/macOS:**

```bash
APKTOOL_VERSION=test docker compose -f examples/docker-compose.decode.yml run --rm decode-apk
```

**Windows (PowerShell):**

```powershell
$env:APKTOOL_VERSION="test"; docker compose -f examples/docker-compose.decode.yml run --rm decode-apk
```
