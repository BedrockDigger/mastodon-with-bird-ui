# Mastodon with Bird UI - Automated Multi-Arch Container Image Builder

Automated GitHub Actions workflow that periodically checks for new stable releases of Mastodon, builds multi-architecture (`linux/amd64` and `linux/arm64`) container images with [Mastodon Bird UI](https://github.com/ronilaukkarinen/mastodon-bird-ui) pre-integrated and precompiled, and pushes them to GitHub Container Registry (GHCR).

This repository is independent of both upstream `mastodon/mastodon` and `ronilaukkarinen/mastodon-bird-ui`.

---

## Table of Contents

1. [Features](#features)
2. [Project Structure](#project-structure)
3. [Release Patterns & Polling Design](#release-patterns--polling-design)
4. [Locale Support & Localization Architecture](#locale-support--localization-architecture)
5. [Setup & Authentication Guide](#setup--authentication-guide)
   - [Option A: Built-in GITHUB_TOKEN](#option-a-built-in-github_token)
   - [Option B: Personal Access Token (CR_PAT)](#option-b-personal-access-token-cr_pat-recommended)
6. [How the Build Works](#how-the-build-works)
7. [Manual Execution & Options](#manual-execution--options)
8. [Using the Resulting Image in Docker Compose](#using-the-resulting-image-in-docker-compose)
9. [Troubleshooting & Bug Fixes Reference](#troubleshooting--bug-fixes-reference)

---

## Features

- **Automated Scheduled Polling:** No external webhooks, third-party relays, or serverless forwarders required.
- **Smart Idempotency (Duplicate Prevention):** Queries GHCR before building; skips build if the image tag already exists, finishing in ~10 seconds.
- **Native Multi-Architecture Distributed Build:** Builds `linux/amd64` and `linux/arm64` in parallel using native runners (`ubuntu-24.04` and `ubuntu-24.04-arm`) without slow QEMU emulation.
- **Complete 106-Language Locale Support:** Extends `scripts/install-to-mastodon.sh` with native translations for Bird UI Accessible and Accessible Plus variations across **all 106 base languages** supported by Mastodon.
- **Native Brand Name Preservation:** Automatically preserves localized names for original Mastodon (e.g., `ماستدون` in Arabic, `ماستودون` in Persian, `מסטودון` in Hebrew) when Bird UI is set as the default theme.
- **Dual Registry Authentication:** Supports both `GITHUB_TOKEN` and personal access tokens (`CR_PAT`) with automatic OCI repository linking (`org.opencontainers.image.source`).
- **Production Asset Precompilation:** Precompiles all assets directly during Docker multi-stage build.

---

## Project Structure

```
mastodon-with-bird-ui/
├── .github/
│   └── workflows/
│       └── build-container-image.yml  # Distributed multi-arch build & merge workflow
├── scripts/
│   └── install-to-mastodon.sh         # Idempotent install script with 106-language locale support
├── .gitignore                         # Standard git ignore rules
└── README.md                          # Full setup and architecture documentation
```

---

## Release Patterns & Polling Design

An analysis of 139+ Mastodon stable releases between 2024 and 2026 revealed the following release patterns:

1. **Release Days:** 
   - **Tuesdays** (41 releases)
   - **Thursdays** (41 releases)
   - **Wednesdays** (32 releases)
   - **Mondays** (16 releases)
   - **Fridays** (9 releases)
   - **Weekends:** 0 releases (Mastodon core maintainers do not release on weekends).

2. **Release Hours (European Time, CET/CEST):**
   - Releases occur almost exclusively during European afternoon working hours: **14:00 – 17:00 CET/CEST** (which corresponds to **12:00 – 16:00 UTC**).

3. **Release Cadence:**
   - Synchronized patch batches across all supported minor branches (e.g. `v4.7.x`, `v4.6.x`, `v4.5.x`, `v4.4.x`) are published every 1 to 2 weeks.

### The Chosen Polling Schedule

```yaml
schedule:
  - cron: '0 6,18 * * *'
```

- **18:00 UTC:** Promptly catches releases published at the close of European working hours (`14:00 – 17:00 CET`).
- **06:00 UTC:** Serves as a catch-up run for any late emergency security releases.
- **Zero-Waste Idempotency:** The workflow inspects GHCR with `docker buildx imagetools inspect`. If the image tag already exists, it exits cleanly without consuming runner minutes.

---

## Locale Support & Localization Architecture

Upstream `mastodon-bird-ui` only provided localized entries for Finnish (`fi.yml`) and defaulted all other languages to English. 

The enhanced installer [`scripts/install-to-mastodon.sh`](file:///Users/estel/projects/mastodon-with-bird-ui/scripts/install-to-mastodon.sh) extends support to **all 106 base languages** supported by Mastodon (filtering out gem-specific files like `activerecord.*`, `devise.*`, `doorkeeper.*`, and `simple_form.*`).

### 1. Standard Digital Accessibility Terminology
Mapped native terms for `mastodon-bird-ui-accessible` and `mastodon-bird-ui-accessible-plus`:
- **German (`de`):** `Barrierefrei` / `Barrierefrei Plus`
- **French (`fr`, `fr-CA`):** `Accessible` / `Accessible Plus`
- **Spanish (`es`, `es-AR`, `es-MX`):** `Accesible` / `Accesible Plus`
- **Italian (`it`):** `Accessibile` / `Accessibile Plus`
- **Portuguese (`pt-BR`, `pt-PT`):** `Acessível` / `Acessível Plus`
- **Dutch (`nl`):** `Toegankelijk` / `Toegankelijk Plus`
- **Japanese (`ja`):** `アクセシブル` / `アクセシブル Plus`
- **Simplified Chinese (`zh-CN`):** `无障碍` / `无障碍 Plus`
- **Traditional Chinese (`zh-TW`, `zh-HK`):** `無障礙` / `無障礙 Plus`
- **Arabic (`ar`):** `إمكانية الوصول` / `إمكانية الوصول بلس`
- **Hebrew (`he`):** `נגיש` / `נגיש פלוס`
- **Russian (`ru`):** `Специальные возможности` / `Специальные возможности Плюс`
- **Ukrainian (`uk`):** `Доступна` / `Доступна Плюс`
- **Finnish (`fi`):** `saavutettava` / `saavutettava Plus`
- **Toki Pona (`tok`):** `pona tawa jan` / `pona tawa jan sin`
- *(...and all other supported languages, falling back safely to English for any future newly added locale).*

### 2. Upstream Brand Name Preservation
When setting Bird UI as the server default (`default: styles/mastodon-bird-ui-auto.scss`), the stock Mastodon theme is moved to `mastodon-dark`. Rather than hardcoding `"Mastodon"`, the script dynamically reads the existing native value under `themes.default` (e.g. `ماستدون` in Arabic, `ماستودون` in Persian, `מסטودון` in Hebrew).

---

## Setup & Authentication Guide

The workflow pushes images to GitHub Container Registry (`ghcr.io/<owner>/mastodon-with-bird-ui`) using dual authentication:

### Option A: Built-in GITHUB_TOKEN
1. In your GitHub repository, navigate to **Settings** > **Actions** > **General**.
2. Under **Workflow permissions**, select **Read and write permissions**.
3. Click **Save**.

### Option B: Personal Access Token (`CR_PAT`) (Recommended)
If your account or organization permissions restrict `GITHUB_TOKEN` from creating new root-level packages (resulting in `denied: permission_denied: write_package`):
1. Create a Personal Access Token (classic) at **GitHub Settings** > **Developer settings** > **Personal access tokens** > **Tokens (classic)**.
2. Select scopes:
   - **`write:packages`** (automatically includes `read:packages`)
   - **`delete:packages`** (optional, for tag cleanup)
3. In this repository, go to **Settings** > **Secrets and variables** > **Actions**.
4. Click **New repository secret**.
5. Name: **`CR_PAT`**
6. Value: Paste your generated token and save.
7. The workflow automatically detects and uses `secrets.CR_PAT` if present, falling back to `GITHUB_TOKEN`.

*(Optional)* After the first successful image push, go to your profile/organization's **Packages** tab, select the container package, and under **Package settings**, set visibility to **Public** to allow pulling without credentials.

---

## How the Build Works

The build replicates the distributed multi-runner pattern from upstream Mastodon (`mastodon/.github/workflows/build-container-image.yml`):

1. **`resolve-release` Job:**
   - Detects the target tag (or queries upstream Mastodon for the latest stable tag).
   - Validates that the tag is a stable release (`^v[0-9]+\.[0-9]+(\.[0-9]+)?$`, rejecting `-rc`, `-beta`, and `-alpha`).
   - Logs into GHCR and queries `docker buildx imagetools inspect`. If the tag already exists (and `force_rebuild` is false), it skips the build.
   - Determines whether the tag is the latest overall stable release for applying the `:latest` tag.

2. **`build-image` Matrix Job (Runs only when a new release is detected):**
   - Runs in parallel on:
     - `ubuntu-24.04` for `linux/amd64`
     - `ubuntu-24.04-arm` for `linux/arm64`
   - Clones upstream Mastodon at the resolved release tag.
   - Clones `ronilaukkarinen/mastodon-bird-ui`.
   - Runs `scripts/install-to-mastodon.sh` with full locale support to inject Bird UI SCSS into `app/javascript/styles/mastodon-bird-ui/`, update `config/themes.yml`, and update `config/locales/*.yml`.
   - Adds OCI source annotations (`org.opencontainers.image.source=https://github.com/<owner>/mastodon-with-bird-ui`).
   - Builds Mastodon's official `Dockerfile` with Docker Buildx. Rails assets are precompiled during the multi-stage build.
   - Pushes each architecture image to GHCR by **digest**.
   - Uploads digests as workflow artifacts.

3. **`merge-images` Job:**
   - Downloads digests from both runners.
   - Assembles the multi-architecture manifest list using `docker buildx imagetools create`.
   - Tags the unified image with:
     - `ghcr.io/<owner>/<repo>:vX.Y.Z`
     - `ghcr.io/<owner>/<repo>:X.Y.Z`
     - `ghcr.io/<owner>/<repo>:vX.Y`
     - `ghcr.io/<owner>/<repo>:latest` (if latest stable release)
   - Inspects the pushed multi-arch manifest.

---

## Manual Execution & Options

You can trigger a build manually at any time via `workflow_dispatch`:

1. In GitHub, go to the **Actions** tab.
2. Select **Build Mastodon Bird UI Container Image**.
3. Click **Run workflow**.
4. Options available:
   - **`tag`**: Target Mastodon release tag (e.g. `v4.3.1`). Leave empty to automatically resolve the latest stable release.
   - **`force_rebuild`**: Force rebuild and push even if the image tag already exists in GHCR.
   - **`bird_ui_ref`**: Git ref for `ronilaukkarinen/mastodon-bird-ui` (default: `main`).
   - **`set_default`**: Set Mastodon Bird UI as the server default theme (`y`/`n`, default: `y`).
   - **`include_variations`**: Include accessible variations (`y`/`n`, default: `y`).

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

---

## Troubleshooting & Bug Fixes Reference

During development and CI testing, three key edge cases were identified and permanently resolved in `scripts/install-to-mastodon.sh`:

1. **`gawk` Regex Escape Warning:**
   - *Issue:* Ubuntu's GNU `awk` warned on regex bracket escapes: `warning: regexp escape sequence \" is not a known regexp operator`.
   - *Fix:* Replaced regex `gsub` with octal ASCII character deletion: `tr -d '\042\047'`.

2. **Subshell Nested Quote Syntax Error:**
   - *Issue:* Command substitutions like `$(... | tr -d '"'\'')` caused bash to interpret trailing quotes as an unclosed string, failing with `syntax error near unexpected token '('`.
   - *Fix:* Using quote-free octal literals `\042\047` eliminated subshell quote-escaping ambiguities entirely.

3. **Ruby `Psych::SyntaxError` (`found character that cannot start any token`):**
   - *Issue:* Unscoped `awk '/^[ ]+default:/'` matched `date.formats.default` (`"%d %b %Y"`) before reaching `themes:`. Stripping quotes produced unquoted `%` characters, which are reserved YAML directives.
   - *Fix:* Scoped extraction and replacement strictly to the `^  themes:` block, with full idempotency verification across all 106 base locales.
