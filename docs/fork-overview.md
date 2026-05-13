# olho-kreuzberg

## Purpose

A maintained fork of [Kreuzberg](https://github.com/kreuzberg-dev/kreuzberg) that adds patches for the Olho project's specific needs:

1. **`base_url` parameter in structured extraction API** — The upstream Kreuzberg structured extraction endpoint does not accept a `base_url` override, forcing hardcoded provider URLs. The Olho project needs to route LLM calls through custom endpoints.
2. **`KREUZBERG_VLM_OCR_API_KEY` environment variable** — Upstream supports `KREUZBERG_VLM_OCR_MODEL` but has no separate `KREUZBERG_VLM_OCR_API_KEY` env var for VLM OCR, making it hard to configure API keys independently.

This fork provides those patches while staying in sync with upstream Kreuzberg.

---

## Features

The fork adds two core patches:

- **`base_url` in structured extraction handler** — Adds `base_url` field to the `/extract/structured` API endpoint, forwarded to `LlmConfig`
- **`KREUZBERG_VLM_OCR_API_KEY` env var** — Adds environment variable support for VLM OCR API key, with proper config merging

See **[fork-features.md](./fork-features.md)** for detailed descriptions and code references.

---

## Installation

### Prerequisites

- **macOS** (Apple Silicon recommended)
- **Rust** (via `rustup`) — [Install](https://rustup.rs/)
- **Git** — for fetching and building
- **Docker** — for building container images

### Quick Install (Recommended)

```bash
# Clone the fork (if not already cloned)
cd ~/www/misc
git clone git@github.com:oleksii-honchar/kreuzberg.git olho-kreuzberg

# Build
cd olho-kreuzberg
cargo build --release
```

### Docker Build

```bash
# Build the patched image
./build-and-push.sh --variant patches --build-only

# Run
docker run -p 8000:8000 olho-kreuzberg:patches-latest
```

---

## Usage

### Using the Forked Library

```bash
# Use the forked library in your project
cargo add --git https://github.com/oleksii-honchar/kreuzberg.git --branch patched/main kreuzberg
```

### Using the Forked Docker Image

```bash
# Build and push
docker login
./build-and-push.sh --variant patches

# Run with custom VLM OCR config
docker run --rm -it \
  -e KREUZBERG_VLM_OCR_MODEL="openai/gpt-4o" \
  -e KREUZBERG_VLM_OCR_API_KEY="sk-..." \
  -p 8000:8000 \
  docker.io/oleksii-honchar/olho-kreuzberg:patches-latest
```

---

## Runbook: Making Changes and Syncing with Source

For detailed governance procedures — fork structure, syncing with upstream, making changes, building, and pushing — see **[GOVERNANCE.md](./GOVERNANCE.md)**.

The governance document covers:
- Fork structure and branch conventions
- Upstream sync procedures (with conflict resolution)
- Feature branch workflow for adding patches
- Build and verification commands
- Push procedures and force-push safety
- Recovery scenarios and common mistakes to avoid

---

## Compatibility

This fork is **backward-compatible** with upstream Kreuzberg. All patches use optional parameters and fields — existing behavior is unchanged when `base_url` is not provided and `KREUZBERG_VLM_OCR_API_KEY` is not set.

---

## License

Elastic License 2.0 (ELv2) — Same as upstream Kreuzberg.
