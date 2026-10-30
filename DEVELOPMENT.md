# Development Guide

This document provides information for developers working on the Apktool Docker image.

## Development Environment

### Prerequisites

- Docker installed and running
- Docker Compose installed
- Git for version control
- Text editor or IDE

### Project Structure

```
docker-apktool/
├── Dockerfile              # Main image definition
├── docker-compose.yml      # Basic usage configuration
├── docker-compose.dev.yml  # Development environment
├── docker-compose.test.yml # Test orchestration
├── .env                    # Default environment variables
├── scripts/
│   └── apktool             # POSIX launcher copied into the image
├── examples/               # Example Docker Compose configurations
│   ├── docker-compose.decode.yml
│   ├── docker-compose.build.yml
│   └── docker-compose.framework.yml
├── test/                   # Container Structure Tests
│   ├── apktool_test.yml
│   ├── apktool_command_test.yml
│   └── apktool_metadata_test.yml
├── workspace/              # Local working directory (bundled sample APK)
│   └── input/hello.apk
└── docs/                   # Documentation assets
```

## Development Workflow

### 1. Local Development Mode

The `docker-compose.dev.yml` file provides an interactive development environment:

```bash
# Build the image locally
docker compose -f docker-compose.dev.yml build

# Run in development mode (interactive shell)
docker compose -f docker-compose.dev.yml run --rm apktool-dev

# Inside the container, you can run apktool manually
apktool --version
apktool d input/hello.apk -o output/hello
apktool b output/hello -o output/hello-rebuilt.apk
```

The development mode:

- Overrides the entrypoint to `/bin/sh` for interactive access
- Mounts the `./workspace` directory for testing files
- Sets a custom prompt to identify the development environment
- Keeps STDIN open and allocates a TTY

### 2. Building the Image

```bash
# Basic build
docker build -t ragedunicorn/apktool:dev .

# Build with version metadata (Apktool and Alpine come from the Dockerfile)
docker build \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg VERSION=dev \
  -t ragedunicorn/apktool:dev .

# Build a different Apktool version than the Dockerfile default
# (the jar checksum must match that version, see "Updating Apktool")
docker build \
  --build-arg APKTOOL_VERSION=<apktool-version> \
  --build-arg APKTOOL_SHA256=<apktool-sha256> \
  -t ragedunicorn/apktool:dev .

# Multi-platform build (requires buildx)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ragedunicorn/apktool:dev .
```

The Apktool version is the `APKTOOL_VERSION` default in the `Dockerfile` and the Alpine version is its `FROM` line.
Renovate keeps both current, so the docs do not repeat them.

### 3. Testing Your Changes

After making changes, always build and test locally:

```bash
# Build your changes locally
docker build -t ragedunicorn/apktool:test .
```

#### Running Tests (Cross-Platform)

**Linux/macOS:**

```bash
# Run all tests against your local build
APKTOOL_TEST_VERSION=test docker compose -f docker-compose.test.yml run test-all

# Run specific tests during development
APKTOOL_TEST_VERSION=test docker compose -f docker-compose.test.yml up container-test-command
```

**Windows Command Prompt:**

```cmd
# Run all tests against your local build
set APKTOOL_TEST_VERSION=test && docker compose -f docker-compose.test.yml run test-all

# Run specific tests during development
set APKTOOL_TEST_VERSION=test && docker compose -f docker-compose.test.yml up container-test-command
```

**Windows PowerShell:**

```powershell
# Run all tests against your local build
$env:APKTOOL_TEST_VERSION="test"; docker compose -f docker-compose.test.yml run test-all

# Run specific tests during development
$env:APKTOOL_TEST_VERSION="test"; docker compose -f docker-compose.test.yml up container-test-command
```

**Important:** Never test against remote images - they may have different labels or configurations due to CI/CD overrides.

See [TEST.md](TEST.md) for detailed testing information.

## Making Changes

### Updating Apktool

Apktool publishes **no checksums** for its release assets, so the Dockerfile pins a self-computed SHA-256 next to the
version:

```dockerfile
# renovate: datasource=github-releases depName=iBotPeaches/Apktool
ARG APKTOOL_VERSION=<apktool-version>
ARG APKTOOL_SHA256=<apktool-sha256>
```

Renovate bumps only `APKTOOL_VERSION`; the build then fails checksum verification until the hash is refreshed. On an
Apktool update PR:

1. Download the new jar and compute its hash:

   ```bash
   curl -fsSLO https://github.com/iBotPeaches/Apktool/releases/download/v<NEW>/apktool_<NEW>.jar
   sha256sum apktool_<NEW>.jar
   ```

2. Compare against the digest GitHub shows on the release page (immutable release digest) — they must match
3. Update `ARG APKTOOL_SHA256` on the Renovate PR branch and push
4. Let CI re-run; the round-trip test validates the new jar end to end

This manual step is deliberate: a checksum that updated itself would verify nothing.

### Version Updates

This project uses [Renovate](https://docs.renovatebot.com/) to automatically manage dependency updates:

- **Apktool**: Renovate monitors [GitHub releases](https://github.com/iBotPeaches/Apktool/releases) and creates PRs
  when a new version is tagged (see the manual checksum step above)
- **Eclipse Temurin**: Renovate monitors the [Adoptium apk repository](https://packages.adoptium.net/) directory
  listing and creates PRs when the pinned `temurin-21-jre` apk package moves
- **Alpine Linux**: Renovate monitors Docker Hub and creates PRs for new Alpine versions

The Alpine version is referenced in several places that must stay aligned:

- The `FROM alpine:X.X.X` lines in the Dockerfile (tracked by Renovate's built-in Dockerfile manager)
- The `org.opencontainers.image.base.name` OCI label in the Dockerfile (tracked by a regex custom manager)
- The Alpine version asserted in `test/apktool_metadata_test.yml` (tracked by a regex custom manager)

All of these resolve to the same `alpine` dependency at the same version, so Renovate bumps them together in a single
PR — the base image, the label, and the metadata test no longer drift apart. No manual sync step is required.

When Renovate creates a PR:

1. Review the changes in the PR
2. Check the CI/CD pipeline passes all tests
3. Test the build locally if it's a major version update
4. Merge the PR if everything looks good

### The Launcher Script

Upstream distributes a bash wrapper for Linux; this image intentionally has no bash, so `scripts/apktool` is a small
POSIX port that sets the same JVM flags and execs `java -jar /usr/local/bin/apktool.jar`. The flags can be replaced at
runtime via the `APKTOOL_JAVA_OPTS` environment variable.

When bumping Apktool major versions, diff the upstream wrapper for new JVM flags and mirror them:
<https://github.com/iBotPeaches/Apktool/blob/master/scripts/linux/apktool>

The script is extensionless, so it is covered by an explicit `scripts/apktool text eol=lf` rule in `.gitattributes`
(the `*.sh` rule does not match it). It must stay LF — a CRLF shebang breaks the image entrypoint with a misleading
`not found` error.

## Code Style and Best Practices

### Dockerfile Best Practices

1. **Multi-stage build**: The jar is downloaded and checksum-verified in a build stage; the runtime stage stays lean
2. **Layer optimization**: Group related commands to minimize layers
3. **Cache efficiency**: Order commands from least to most frequently changed
4. **Security**: Run as a non-root user; verify downloaded artifacts
5. **Labels**: Follow OCI naming conventions

### Documentation

1. **README.md**: Keep focused on user-facing information
2. **Comments**: Add comments in Dockerfile for complex operations
3. **Examples**: Provide working examples for new features
4. **Commit messages**: Use conventional format (feat:, fix:, docs:, etc.)

### Testing

1. **Test everything**: New features must include tests
2. **Test edge cases**: Include negative tests where appropriate
3. **Keep tests fast**: Avoid long-running operations in tests
4. **Test organization**: Group related tests together

## Debugging

### Common Issues

**Build failures:**

```bash
# Verbose build output
docker build --progress=plain --no-cache -t ragedunicorn/apktool:debug .
```

A checksum mismatch in the build stage means `APKTOOL_VERSION` and `APKTOOL_SHA256` are out of sync — see
"Updating Apktool" above.

**Entrypoint fails with `not found`:**

The wrapper picked up CRLF line endings (Windows checkout without the `.gitattributes` rule). Verify:

```bash
docker run --rm --entrypoint sh ragedunicorn/apktool:dev -c "od -c /usr/local/bin/apktool | head -2"
```

Any `\r` in the output confirms it. Fix the checkout (`git checkout -- scripts/apktool` after ensuring
`.gitattributes` is present) and rebuild.

**`apktool b` fails while `apktool d` works:**

Building invokes the aapt2 binary that Apktool extracts from its jar at runtime — a glibc x86_64 binary that runs on
Alpine only through the `gcompat` shim (and not at all on arm64). To inspect it:

```bash
# Extract the bundled aapt2 and check its dynamic dependencies
docker run --rm --user root --entrypoint sh ragedunicorn/apktool:dev -c \
  "unzip -o -q /usr/local/bin/apktool.jar prebuilt/linux/aapt2 -d /tmp && ldd /tmp/prebuilt/linux/aapt2"

# Run it directly to see the loader error, if any
docker run --rm --user root --entrypoint sh ragedunicorn/apktool:dev -c \
  "unzip -o -q /usr/local/bin/apktool.jar prebuilt/linux/aapt2 -d /tmp && chmod +x /tmp/prebuilt/linux/aapt2 && /tmp/prebuilt/linux/aapt2 version"
```

If a future aapt2 build reports a missing `libstdc++.so.6`, add `libstdc++` to the runtime `apk add` list in the
Dockerfile.

**Framework directory issues:**

Apktool aborts (even on decode) when it cannot create its framework directory. In this image it is pre-created at
`/home/apktool/.local/share/apktool/framework` and owned by the `apktool` user. When mounting a volume there, make
sure it is writable for uid 1000, or use `--frame-path` to relocate it into the mounted workspace.

## Contributing

### Before Submitting Changes

1. Run the full test suite
2. Update documentation if needed
3. Add tests for new features
4. Ensure your code follows the existing style
5. Write clear commit messages

### Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes using conventional commits
4. Push to your fork
5. Open a Pull Request with a clear description

### Release Process

See [RELEASE.md](RELEASE.md) for information about creating releases.
