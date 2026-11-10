# Mastodon with Bird UI - Automated Multi-Arch Container Image Builder

Automated GitHub Actions workflow that periodically checks for new stable releases of Mastodon, builds multi-architecture (`linux/amd64` and `linux/arm64`) container images with [Mastodon Bird UI](https://github.com/ronilaukkarinen/mastodon-bird-ui) pre-integrated and precompiled, then pushes them to GitHub Container Registry (GHCR).

This repository is independent of both upstream `mastodon/mastodon` and `ronilaukkarinen/mastodon-bird-ui`.

---

## Mastodon Release Patterns & Polling Design

An analysis of 139+ Mastodon stable releases between 2024 and 2026 shows clear patterns:

1. **Release Days:** 
   - **Tuesdays** (41 releases)
   - **Thursdays** (41 releases)
   - **Wednesdays** (32 releases)
   - **Mondays** (16 releases)
   - **Fridays** (9 releases)
   - **Weekends:** 0 releases (Mastodon core maintainers do not release on weekends).

2. **Release Hours (European Time, CET/CEST):**
   - Releases occur almost exclusively during European afternoon working hours: **14:00 – 17:00 CET/CEST** (which corresponds to **12:00 – 16:00 UTC**).

3. **Release Frequency:**
   - On average, releases occur every 1 to 2 weeks, typically publishing synchronized maintenance/security batches across all supported branches (e.g. `v4.7.x`, `v4.6.x`, `v4.5.x`, `v4.4.x`).

### The Chosen Polling Schedule

```yaml
schedule:
  - cron: '0 6,18 * * *'
```

- **Runs twice daily:** at `06:00 UTC` and `18:00 UTC`.
- The `18:00 UTC` run catches new releases shortly after European working hours conclude (`14:00 - 17:00 CET`).
- The `06:00 UTC` run catches any late emergency or security patches.
- **Smart Idempotency (Skip when already built):** Every run checks if `ghcr.io/<owner>/<repo>:<tag>` already exists in GHCR using `docker buildx imagetools inspect`. If the tag is already present, the workflow terminates within ~10 seconds, consuming virtually zero runner minutes.

---

## Features

- **Automated Scheduled Polling:** No external webhooks, third-party relays, or serverless forwarders required.
- **Duplicate Prevention:** Skips build if the release image tag already exists in GHCR. Supports `--force-rebuild` via manual dispatch.
- **Native Multi-Architecture Distributed Build:** Builds `linux/amd64` and `linux/arm64` in parallel using native runners (`ubuntu-24.04` and `ubuntu-24.04-arm`) following Docker's distributed build pattern.
- **Complete Locale Support:** Extends `scripts/install-to-mastodon.sh` to support **all 106 languages** natively supported by Mastodon with localized labels for Bird UI Accessible and Accessible Plus variations.
- **GHCR Registry:** Pushes images to `ghcr.io/<owner>/<repo>` with proper semver tags (`vX.Y.Z`, `X.Y.Z`, `vX.Y`) and updates the `latest` tag only for the latest stable release.
- **Production Asset Compilation:** Runs Rails asset precompilation during the Docker build so assets are bundled directly into the container image.

---

## Project Structure

```
mastodon-with-bird-ui/
├── .github/
│   └── workflows/
│       └── build-container-image.yml  # Distributed multi-arch build & merge workflow
├── scripts/
│   └── install-to-mastodon.sh         # Idempotent install script with 106-language locale support
└── README.md                          # Setup and operations guide
```

---

## Setup Guide

### 1. Registry Authentication (GHCR Access)

The workflow supports authenticating to GitHub Container Registry (`ghcr.io`) via either the built-in `GITHUB_TOKEN` or a Personal Access Token (`CR_PAT`):

#### Option A: Built-in GITHUB_TOKEN
1. In your GitHub repository, navigate to **Settings** > **Actions** > **General**.
2. Under **Workflow permissions**, select **Read and write permissions**.
3. Click **Save**.

#### Option B: Personal Access Token (Classic) (Recommended if write_package is denied)
If your account or organization policies restrict `GITHUB_TOKEN` from creating new root-level packages:
1. Create a Personal Access Token (classic) at **GitHub Settings** > **Developer settings** > **Personal access tokens** > **Tokens (classic)**.
2. Select scopes: `write:packages`, `read:packages`, and `delete:packages`.
3. In this repository, go to **Settings** > **Secrets and variables** > **Actions**.
4. Add a repository secret named **`CR_PAT`** with your token as the value.
5. The workflow automatically detects and uses `secrets.CR_PAT` if present, falling back to `GITHUB_TOKEN`.

---

### 2. Manual Execution & Options

You can trigger a build manually at any time via `workflow_dispatch`:

1. In GitHub, go to the **Actions** tab.
2. Select **Build Mastodon Bird UI Container Image**.
3. Click **Run workflow**.
4. Options available:
   - **`tag`**: Target Mastodon release tag (e.g. `v4.3.1`). Leave empty to automatically build the latest stable release.
   - **`force_rebuild`**: Check to recompile and push even if the image tag already exists in GHCR.
   - **`set_default`**: Set Mastodon Bird UI as the server default theme (`y`/`n`, default: `y`).
   - **`include_variations`**: Include accessible variations (`y`/`n`, default: `y`).

---

## How the Build Works

The workflow distributes the build process across two native runners to eliminate cross-compilation overhead:

1. **`resolve-release` Job:**
   - Resolves the target tag (or queries upstream Mastodon for the latest stable tag).
   - Validates that the tag is a stable release (e.g. `v4.7.5`, rejecting `-rc`, `-beta`, `-alpha`).
   - Logs into GHCR and queries `docker buildx imagetools inspect`. If the tag already exists and `force_rebuild` is false, it marks `should_build=false` and exits.

2. **`build-image` Matrix Job (Runs only when `should_build=true`):**
   - Runs in parallel on:
     - `ubuntu-24.04` for `linux/amd64`
     - `ubuntu-24.04-arm` for `linux/arm64`
   - Clones upstream Mastodon at the specified release tag.
   - Clones `ronilaukkarinen/mastodon-bird-ui`.
   - Runs `scripts/install-to-mastodon.sh` with full locale support to copy Bird UI SCSS into `app/javascript/styles/mastodon-bird-ui/`, configure `config/themes.yml`, and inject translated theme labels into `config/locales/*.yml`.
   - Builds Mastodon's official `Dockerfile` with Docker Buildx. Rails assets are precompiled during the multi-stage build.
   - Pushes each platform image to GHCR by **digest**.
   - Uploads the digest as a workflow artifact.

3. **`merge-images` Job:**
   - Downloads digests from both runners.
   - Assembles the multi-architecture manifest list using `docker buildx imagetools create`.
   - Tags the unified image with:
     - `ghcr.io/<owner>/<repo>:v4.7.5`
     - `ghcr.io/<owner>/<repo>:4.7.5`
     - `ghcr.io/<owner>/<repo>:v4.7`
     - `ghcr.io/<owner>/<repo>:latest` (if latest stable release)
   - Inspects the pushed multi-arch manifest.

---

## Using the Resulting Image in Docker Compose

Update your `docker-compose.yml` to use your GHCR image:

```yaml
services:
  web:
    image: ghcr.io/<YOUR_GITHUB_USER_OR_ORG>/mastodon-with-bird-ui:latest
    restart: always
    env_file: .env.production
    command: bundle exec puma -C config/puma.rb
    # ...
  sidekiq:
    image: ghcr.io/<YOUR_GITHUB_USER_OR_ORG>/mastodon-with-bird-ui:latest
    restart: always
    env_file: .env.production
    command: bundle exec sidekiq
    # ...
```

Pull the image:
```bash
docker compose pull
docker compose up -d
```
