# Testing Guide

This document describes how to test the Apktool Docker image using Container Structure Tests.

## Quick Start

```bash
# Run all tests
docker compose -f docker-compose.test.yml run test-all

# Run individual test suites
docker compose -f docker-compose.test.yml up container-test          # File structure tests
docker compose -f docker-compose.test.yml up container-test-command  # Command execution tests
docker compose -f docker-compose.test.yml up container-test-metadata # Metadata validation tests
```

## Test Structure

The test suite consists of three main test files plus a functional round trip in CI:

### 1. File Structure Tests (`test/apktool_test.yml`)

Validates:

- The `apktool` wrapper script and `apktool.jar` exist with the right permissions
- The Temurin 21 JRE is installed
- The gcompat glibc loader shim is present (needed by the aapt2 binary bundled inside apktool.jar)
- The framework directory `/home/apktool/.local/share/apktool/framework` exists
- Working directory `/workspace` exists and is accessible
- CA certificates are present
- The wrapper actually launches the Apktool jar

### 2. Command Execution Tests (`test/apktool_command_test.yml`)

Validates:

- Apktool version output
- The wrapper resolves on `PATH`
- The Java runtime version (Temurin 21)
- The non-root `apktool` user exists
- Working directory functionality and writability
- Framework directory writability (Apktool aborts even on decode if it cannot write there)

### 3. Metadata Tests (`test/apktool_metadata_test.yml`)

Validates:

- OCI-compliant labels are present and correct
- `JAVA_HOME` and `LANG` environment variables
- Container entrypoint and default command
- Working directory configuration
- User context (runs as the non-root `apktool` user)

### 4. Round Trip Test (CI only)

The test workflow additionally decodes and rebuilds the bundled sample APK (`workspace/input/hello.apk`) inside the
freshly built image. This exercises the full pipeline — framework extraction, resource decoding, and the
gcompat-backed aapt2 rebuild — which the Container Structure Tests cannot cover because the sample APK is not part of
the image.

## The Sample APK

`workspace/input/hello.apk` is a ~1 KB self-made APK (binary `AndroidManifest.xml` plus a single string resource)
used by the CI round trip and the examples. It was generated with the aapt2 binary that ships inside the Apktool jar,
so no third-party binary enters the repository. To regenerate it:

```bash
# Build the image first: docker build -t ragedunicorn/apktool:test .
docker run --rm --user root -v "$PWD/workspace/input:/out" \
  --entrypoint sh ragedunicorn/apktool:test -c '
    set -eu
    cd /tmp
    unzip -o -q /usr/local/bin/apktool.jar prebuilt/linux/aapt2 -d .
    chmod +x prebuilt/linux/aapt2
    mkdir -p res/values compiled
    printf "%s\n%s\n" \
      "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\"" \
      "    package=\"com.ragedunicorn.hello\"/>" > AndroidManifest.xml
    printf "%s\n%s\n%s\n" \
      "<resources>" \
      "    <string name=\"app_name\">Hello</string>" \
      "</resources>" > res/values/strings.xml
    ./prebuilt/linux/aapt2 compile res/values/strings.xml -o compiled/
    ./prebuilt/linux/aapt2 link -o /out/hello.apk --manifest AndroidManifest.xml compiled/*.flat'
```

The string resource is required: an APK without a resource table round-trips with an empty package name, which
`apktool b` rejects (`all packages being linked must have a name`).

## Running Tests

### Prerequisites

1. Docker must be installed and running
2. Build the Apktool image locally before testing

### Important: Always Test Local Builds

**⚠️ Always build and test locally to ensure consistency:**

```bash
# Build the image locally with a test tag
docker build -t ragedunicorn/apktool:test .
```

**Linux/macOS:**

```bash
# Run tests against your local build
APKTOOL_VERSION=test docker compose -f docker-compose.test.yml run test-all
```

**Windows (PowerShell):**

```powershell
# Run tests against your local build
$env:APKTOOL_VERSION="test"; docker compose -f docker-compose.test.yml run test-all
```

**Windows (Command Prompt):**

```cmd
# Run tests against your local build
set APKTOOL_VERSION=test && docker compose -f docker-compose.test.yml run test-all
```

**Why local testing is important:**
- Remote images (Docker Hub, GHCR) may have different labels due to CI/CD overrides
- Ensures you're testing exactly what you built
- Avoids false positives/negatives from version mismatches
- Guarantees consistent test results

**Note:** the repository `.env` file sets `APKTOOL_VERSION=latest` for regular compose usage. Docker Compose loads it
automatically, so the `test` fallback in `docker-compose.test.yml` never applies — always set `APKTOOL_VERSION=test`
explicitly when running the test suites (the `.run` configurations do this for you).

**Never pull remote images for testing:**

**❌ DON'T DO THIS - may have different labels/settings:**

```bash
docker pull ragedunicorn/apktool:latest
docker compose -f docker-compose.test.yml run test-all
```

**✅ DO THIS - test your local build:**

Linux/macOS:

```bash
docker build -t ragedunicorn/apktool:test .
APKTOOL_VERSION=test docker compose -f docker-compose.test.yml run test-all
```

Windows (PowerShell):

```powershell
docker build -t ragedunicorn/apktool:test .
$env:APKTOOL_VERSION="test"; docker compose -f docker-compose.test.yml run test-all
```

### Test Execution

Run specific test categories:

**Linux/macOS:**

```bash
# File structure tests
APKTOOL_VERSION=test docker compose -f docker-compose.test.yml up container-test

# Command execution tests
APKTOOL_VERSION=test docker compose -f docker-compose.test.yml up container-test-command

# Metadata and label tests
APKTOOL_VERSION=test docker compose -f docker-compose.test.yml up container-test-metadata
```

**Windows (PowerShell):**

```powershell
# File structure tests
$env:APKTOOL_VERSION="test"; docker compose -f docker-compose.test.yml up container-test

# Command execution tests
$env:APKTOOL_VERSION="test"; docker compose -f docker-compose.test.yml up container-test-command

# Metadata and label tests
$env:APKTOOL_VERSION="test"; docker compose -f docker-compose.test.yml up container-test-metadata
```

### Running the Round Trip Locally

The CI round trip can be reproduced locally:

```bash
docker run --rm -v "$PWD/workspace/input:/input:ro" --entrypoint sh ragedunicorn/apktool:test -c \
  "apktool d /input/hello.apk -o /workspace/hello && \
   apktool b /workspace/hello -o /workspace/hello-rebuilt.apk && \
   test -s /workspace/hello-rebuilt.apk && \
   echo 'Round trip OK'"
```

Outputs are written inside the container on purpose — the image user (uid 1000) may not be allowed to write to
bind-mounted host directories on CI runners.

## Troubleshooting Test Failures

### aapt2 / Rebuild Failures

`apktool b` runs the glibc aapt2 binary bundled inside the jar; on Alpine it only works through the `gcompat` shim.
See the debugging section in [DEVELOPMENT.md](DEVELOPMENT.md) for commands to extract and inspect the binary.

### Metadata Test Failures

**Common causes:**

1. **Testing remote images instead of local builds**
   - Remote images (Docker Hub, GHCR) have labels overridden by CI/CD
   - Always test your local builds with `APKTOOL_VERSION=test`

2. **Label value mismatches**
   - CI/CD systems may capitalize values (e.g., "RagedUnicorn" vs "ragedunicorn")
   - GitHub Actions may override labels during build
   - Docker Hub automated builds may set different values

3. **Version-specific labels**
   - The `org.opencontainers.image.version` label changes with each build
   - Build date labels are dynamic

4. **Alpine base image drift**
   - `test/apktool_metadata_test.yml` asserts `org.opencontainers.image.base.name` (e.g. `docker.io/library/alpine:X.X.X`)
   - This value must match the `FROM alpine:X.X.X` lines and the `base.name` label in the Dockerfile
   - Renovate keeps all three in sync: the Alpine version in the metadata test and the Dockerfile label are tracked by
     regex custom managers, so they bump together with the `FROM` line in a single `alpine` PR and no longer drift apart
   - If you bump Alpine manually, update the metadata test value in the same change

### Permission Errors

If you encounter Docker socket permission errors:

```bash
sudo docker compose -f docker-compose.test.yml run test-all
```

Or ensure your user is in the `docker` group:

```bash
sudo usermod -aG docker $USER
# Log out and back in for changes to take effect
```

## Writing New Tests

To add new tests, follow the Container Structure Test schema:

1. **File tests**: Add to `test/apktool_test.yml`
2. **Command tests**: Add to `test/apktool_command_test.yml`
3. **Metadata tests**: Add to `test/apktool_metadata_test.yml`

Example of adding a new command test:

```yaml
- name: 'Check decode help output'
  command: 'apktool'
  args: ['d', '--help']
  expectedOutput:
    - 'decode'
  exitCode: 0
```

Note that command tests run without a populated `$HOME` — use absolute paths (e.g.
`/home/apktool/...`) instead of `$HOME` in shell probes.

## CI/CD Integration

These tests are automatically run in GitHub Actions:

- **On every push** to master branches
- **On every pull request** to master branches
- **Before releases** to ensure quality

The test workflow (`.github/workflows/test.yml`):
1. Builds the Docker image
2. Runs all Container Structure Tests
3. Decodes and rebuilds the bundled sample APK (round trip)
4. Blocks releases if tests fail

Manual integration example:

```yaml
- name: Run Container Structure Tests
  env:
    APKTOOL_VERSION: test
  run: docker compose -f docker-compose.test.yml run test-all
```

The `test-all` service returns:
- Exit code 0: All tests passed
- Exit code 1: One or more tests failed

## Test Maintenance

When updating the Docker image:

1. **Apktool version updates**: Usually no test changes needed (the version check asserts `3.0`, which only needs
   loosening on a minor version jump). The pinned `APKTOOL_SHA256` in the Dockerfile must be refreshed manually —
   see DEVELOPMENT.md
2. **Alpine version updates**: The Alpine version in `test/apktool_metadata_test.yml` is kept in sync with the
   Dockerfile by Renovate (same `alpine` dependency bumps everywhere together)
3. **Temurin major version updates**: Update the Java version assertions in `test/apktool_command_test.yml` and the
   `JAVA_HOME` value in `test/apktool_metadata_test.yml`
4. **Label changes**: Update metadata tests to match new labels

Always run the full test suite before creating a release.
