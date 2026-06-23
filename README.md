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

The workflow [Build Mastodon with Bird UI](file:///.github/workflows/build-image.yml) performs the following steps:

1. **Upstream Release Detection**: Queries the GitHub API for the latest release of `mastodon/mastodon`.
2. **Pre-build Check**: Checks if the target version tag has already been built and exists in GHCR (skips if it does).
3. **Integration**:
   - Clones `mastodon/mastodon` at the target version.
   - Clones `rollecode/mastodon-bird-ui`.
   - Runs the Bird UI installation script with the `-d` (default) flag.
   - Creates a dedicated YAML locale file (`config/locales/zzz-bird-ui.yml`) to correctly rename the default Bird UI theme to `"Mastodon Bird UI"` and keep the original dark theme as `"Mastodon"`.
4. **Multi-Arch Compilation**:
   - Compiles the amd64 image on `ubuntu-24.04`.
   - Compiles the arm64 image on `ubuntu-24.04-arm`.
   - Uploads build digests as artifacts.
5. **Manifest Creation**: Merges the platform-specific digests into a single multi-arch manifest tag and pushes it to `ghcr.io/bedrockdigger/mastodon-with-bird-ui`.

### Manual Trigger / Overrides
You can manually run the workflow via the **Actions** tab on GitHub:
- **Force rebuild**: Force-rebuilds and overwrites the existing tag in GHCR even if it already exists.
- **Custom Tag**: Specify a specific Mastodon version tag (e.g., `v4.2.9`) to build that specific version rather than the latest stable one.

## 📄 License
This repository is licensed under the [MIT License](LICENSE). Mastodon and Bird UI are owned and licensed by their respective creators.
