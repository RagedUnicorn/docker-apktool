# Release Process

This document describes how to create a new release for the Docker Apktool project.

## Quick Start

```bash
# Tag format: v{apktool_version}-alpine{alpine_version}-{build_number}
# Take the versions from the Dockerfile (APKTOOL_VERSION and the FROM line)
TAG=v<apktool-version>-alpine<alpine-version>-<build>
git tag -a "$TAG" -m "$TAG"
git push origin "$TAG"
```

This automatically triggers the release process via GitHub Actions.

## Version Tag Format

See [README.md](README.md#versioning) for the complete versioning documentation.

**Format:** `v{apktool_version}-alpine{alpine_version}-{build_number}`

Examples (`X.Y.Z` is the Apktool version, `A.B.C` the Alpine version):
- `vX.Y.Z-alpineA.B.C-1` - Initial release
- `vX.Y.Z-alpineA.B.C-2` - Rebuild with same versions
- `vX.Y.Z-alpineA.B.D-1` - Alpine update (build resets to 1)
- `vX.Y+1.0-alpineA.B.C-1` - Apktool update (build resets to 1)

## Release Workflow

When you push a tag, GitHub Actions automatically:

1. **Builds Docker images** (`.github/workflows/docker_release.yml`)
   - Re-runs the Container Structure Tests as a gate
   - Multi-platform: linux/amd64 and linux/arm64
   - Pushes to both GitHub Container Registry and Docker Hub

2. **Creates GitHub Release** (`create-release` job in `.github/workflows/docker_release.yml`)
   - Runs only after the images were tested and pushed successfully
   - Generates changelog from commit history
   - Adds Docker pull commands
   - Links to the release

## When to Create a Release

Create a new release when:

1. **Renovate updates dependencies** - After merging Renovate PRs for Alpine, Apktool, or Temurin updates
   (Apktool PRs additionally need the manual `APKTOOL_SHA256` refresh — see DEVELOPMENT.md)
2. **Bug fixes** - After fixing issues in the Dockerfile or build process
3. **Feature additions** - After changes to the launcher script or image contents
4. **Security patches** - Immediately after security-related updates

### Build Number Guidelines

- **Reset to 1**: When Apktool or Alpine version changes
- **Increment**: When rebuilding with the same versions (fixes, optimizations)

## Post-Release Tasks

### Update Docker Hub Documentation

`DOCKERHUB.md` is the source of truth for the Docker Hub repository description. It deliberately contains no concrete
versions (readers find those in the Tags tab), so a release alone does not require a description update. Only when
`DOCKERHUB.md` changed since the last sync:

1. Go to [Docker Hub](https://hub.docker.com/r/ragedunicorn/apktool)
2. Click "Manage Repository" → "Description"
3. Copy the contents of `DOCKERHUB.md`
4. Save the changes

**Note**: the sync stays manual on purpose. Docker Hub only offers an undocumented endpoint for description updates, and
it needs a separate Read/Write/Delete access token.

## Best Practices

### Commit Messages

Use conventional commit format for better changelogs:

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `chore:` Maintenance tasks
- `refactor:` Code refactoring
- `test:` Test additions/changes
- `perf:` Performance improvements

Example:
```bash
git commit -m "feat: raise default JVM heap in launcher"
git commit -m "fix: correct working directory permissions"
git commit -m "docs: update usage examples"
```

### Pre-release Testing

Before creating a release:

1. Test the Docker image locally with your version changes
2. Verify the decode/rebuild round trip against the bundled sample APK (see TEST.md)
3. Check that multi-platform builds work (arm64 supports decoding only — see README.md, Architecture Support)

## Troubleshooting

### Release didn't trigger

- Ensure tag starts with `v` and follows the format (e.g., `vX.Y.Z-alpineA.B.C-N`)
- Check GitHub Actions tab for workflow runs
- Verify you have push permissions

### Docker build failed

- Check the Docker workflow logs
- Ensure Dockerfile builds locally
- A checksum mismatch means `APKTOOL_VERSION` and `APKTOOL_SHA256` are out of sync (see DEVELOPMENT.md)
- Verify multi-platform compatibility

### Missing permissions

Ensure your repository has:
- GitHub Actions enabled
- Package write permissions for workflows
- Proper secrets configuration (GITHUB_TOKEN is automatic)

### Docker Hub Configuration

To enable Docker Hub deployment, you need to add these secrets to your GitHub repository:

1. Go to Settings → Secrets and variables → Actions
2. Add the following secrets:
   - `DOCKERHUB_USERNAME`: Your Docker Hub username
   - `DOCKERHUB_TOKEN`: Your Docker Hub access token (not password)

To create a Docker Hub access token:
1. Log in to Docker Hub
2. Go to Account Settings → Security
3. Click "New Access Token"
4. Give it a descriptive name (e.g., "GitHub Actions")
5. Copy the token and add it as `DOCKERHUB_TOKEN` secret

## Manual Release (if needed)

If automation fails, you can create a release manually:

1. Go to repository's "Releases" page
2. Click "Create a new release"
3. Choose your tag (must follow format: `vX.Y.Z-alpineA.B.C-N`)
4. Add release notes
5. Include Docker pull commands (the tag without the leading `v`):
   ```
   docker pull ghcr.io/ragedunicorn/docker-apktool:<tag>
   docker pull ragedunicorn/apktool:<tag>
   ```
