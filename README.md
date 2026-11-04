# Mastodon with Bird UI

[![Build Mastodon with Bird UI](https://github.com/BedrockDigger/mastodon-with-bird-ui/actions/workflows/build-image.yml/badge.svg)](https://github.com/BedrockDigger/mastodon-with-bird-ui/actions/workflows/build-image.yml)

This repository provides an automated GitHub Actions workflow to build and publish a custom Docker image of [Mastodon](https://github.com/mastodon/mastodon) with the [Bird UI](https://github.com/rollecode/mastodon-bird-ui) theme pre-installed and configured as the default theme.

## 🚀 Key Features

- **Automated Upstream Checking**: A scheduled cron job runs every 6 hours to check for new stable releases of Mastodon.
- **Native Multi-Arch Support**: Builds both `linux/amd64` and `linux/arm64` images using native GitHub runner architectures (no QEMU emulation) for maximum build speed.
- **Efficient Caching**: Uses Docker Buildx with GitHub Actions caching to reuse layers across builds.
- **Clean Theme Separation**: Properly resolves duplicate "Mastodon" theme options in the UI, separating them into "Mastodon" (default dark) and "Mastodon Bird UI".
- **Default Integration**: Sets the Bird UI theme as the default theme automatically.

## 🐳 How to Use

The built multi-arch Docker image is published to the GitHub Container Registry (GHCR).

You can use it in your `docker-compose.yml` by replacing the official Mastodon image with this custom one:

```yaml
services:
  web:
    image: ghcr.io/bedrockdigger/mastodon-with-bird-ui:latest
    # ... rest of your configuration
```

### Supported Tags
- `latest`: Always points to the image built from the latest stable Mastodon release.
- `<version>` (e.g., `v4.3.0`): Points to the image built for a specific Mastodon release version.

## 🛠️ GitHub Actions Workflow Details

The workflow [Build Mastodon with Bird UI](.github/workflows/build-image.yml) performs the following steps:

1. **Upstream Release Detection**: Queries the latest stable release of `mastodon/mastodon` via `gh api` (a manually supplied tag bypasses the lookup).
2. **Pre-build Check**: Inspects the target version tag in GHCR and skips the build when it already exists.
3. **Integration**:
   - Clones `mastodon/mastodon` at the target version.
   - Clones `rollecode/mastodon-bird-ui`.
   - Runs the Bird UI installation script with the `-v` (all variations) and `-d` (default theme) flags.
   - Rewrites every locale file so the default theme reads `"Mastodon Bird UI"` while the original dark theme is exposed as `"Mastodon"`, and adds the accessible variants to each locale's theme list.
4. **Multi-Arch Compilation**:
   - Compiles the amd64 image on `ubuntu-24.04`.
   - Compiles the arm64 image on `ubuntu-24.04-arm`.
   - Uploads build digests as artifacts.
5. **Manifest Creation**: Merges the platform-specific digests into a single multi-arch manifest tag and pushes it to `ghcr.io/bedrockdigger/mastodon-with-bird-ui`.

### Build Efficiency
- **Serialised runs**: a `concurrency` group keyed on the branch means only one build runs at a time, so the 6-hourly schedule can never launch a second multi-hour build on top of a still-running one. Pushes to the default branch supersede each other.
- **No wasted builds**: documentation-only pushes (`*.md`, `LICENSE`, `.github/**`) do not trigger a rebuild — the image content does not depend on them.
- **Bounded cost**: each job has an explicit `timeout-minutes`, so a hung build cannot consume the 6-hour default on both runners.
- **Native runners**: amd64 and arm64 compile on their own native GitHub runners (no QEMU emulation), with per-architecture Buildx layer caches.

### Manual Trigger / Overrides
You can manually run the workflow via the **Actions** tab on GitHub:
- **Force rebuild**: Force-rebuilds and overwrites the existing tag in GHCR even if it already exists.
- **Custom Tag**: Specify a specific Mastodon version tag (e.g., `v4.2.9`) to build that specific version rather than the latest stable one.

## 📄 License
This repository is licensed under the [MIT License](LICENSE). Mastodon and Bird UI are owned and licensed by their respective creators.
