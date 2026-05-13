# olho-kreuzberg Fork Features

This document describes the two core patches added by the `olho-kreuzberg` fork.

For an overview of the fork's purpose and installation, see [fork-overview.md](./fork-overview.md).

---

## 1. `base_url` in Structured Extraction API Handler

📋 [Detailed Spec](./spec/01-base-url-structured-extraction.md)

**Status:** ✅ Implemented (working tree, not yet committed)

**Problem:** The upstream Kreuzberg `/extract/structured` API endpoint accepts `model`, `api_key`, `prompt`, and `strict` as multipart form fields, but does **not** accept `base_url`. This means LLM calls always go to the provider's default endpoint, making it impossible to route through custom proxies or local endpoints.

**Solution:** Added `base_url` as an optional multipart form field, forwarded to `LlmConfig.base_url` in the structured extraction handler.

**Code changes:**
- `crates/kreuzberg/src/api/handlers.rs` — Added `base_url` field parsing in `extract_structured_handler`, passed to `LlmConfig`

**API usage:**
```bash
curl -X POST http://localhost:8000/extract/structured \
  -F "file=@document.pdf" \
  -F "schema={\"type\": \"object\", \"properties\": {\"title\": {\"type\": \"string\"}}}" \
  -F "model=openai/gpt-4o" \
  -F "api_key=sk-..." \
  -F "base_url=https://my-custom-proxy.example.com" \
  -F "strict=true"
```

**Before (upstream):**
```rust
llm: crate::core::config::llm::LlmConfig {
    model: model_str,
    api_key,
    base_url: None,  // always None
    timeout_secs: None,
    max_retries: None,
    temperature: None,
}
```

**After (fork):**
```rust
llm: crate::core::config::llm::LlmConfig {
    model: model_str,
    api_key,
    base_url,  // from multipart form field
    timeout_secs: None,
    max_retries: None,
    temperature: None,
}
```

---

## 2. `KREUZBERG_VLM_OCR_API_KEY` Environment Variable

📋 [Detailed Spec](./spec/02-vlm-ocr-api-key-env.md)

**Status:** ✅ Implemented (working tree, not yet committed)

**Problem:** Upstream Kreuzberg supports `KREUZBERG_VLM_OCR_MODEL` to set the VLM OCR model, but has no separate `KREUZBERG_VLM_OCR_API_KEY` environment variable. This means the API key for VLM OCR must come from the general `KREUZBERG_LLM_API_KEY` or be configured programmatically — not ideal for containerized deployments where VLM OCR uses a different provider than structured extraction.

**Solution:** Added `KREUZBERG_VLM_OCR_API_KEY` environment variable support in `ExtractionConfig::from_env`. It sets the `api_key` on the VLM OCR `LlmConfig`, creating one if needed.

**Code changes:**
- `crates/kreuzberg/src/core/config/extraction/env.rs` — Added `KREUZBERG_VLM_OCR_API_KEY` env var handling in `from_env`

**Environment usage:**
```bash
# Set VLM OCR model and API key independently
export KREUZBERG_VLM_OCR_MODEL="openai/gpt-4o"
export KREUZBERG_VLM_OCR_API_KEY="sk-vlm-..."

# Structured extraction can use a different key
export KREUZBERG_LLM_API_KEY="sk-extract-..."
```

**Before (upstream):**
```rust
// Only KREUZBERG_VLM_OCR_MODEL was supported
// KREUZBERG_VLM_EMBEDDING_MODEL was supported
// No KREUZBERG_VLM_OCR_API_KEY
```

**After (fork):**
```rust
// KREUZBERG_VLM_OCR_API_KEY override
if let Ok(value) = std::env::var("KREUZBERG_VLM_OCR_API_KEY") {
    if value.is_empty() {
        return Err(KreuzbergError::Validation { ... });
    }
    // Sets api_key on ocr.vlm_config, creating it if needed
    ...
}
```

---

## 3. `Dockerfile.kreuzberg`

**Status:** ✅ Implemented (working tree, not yet committed)

**Purpose:** Dockerfile for building and running the Kreuzberg API server with the Olho fork patches.

**Code changes:**
- `Dockerfile.kreuzberg` — New file

**Usage:**
```bash
# Build
docker build -f Dockerfile.kreuzberg -t olho-kreuzberg .

# Run with custom VLM OCR config
docker run --rm -it \
  -e KREUZBERG_VLM_OCR_MODEL="openai/gpt-4o" \
  -e KREUZBERG_VLM_OCR_API_KEY="sk-..." \
  -p 8000:8000 \
  olho-kreuzberg
```

---

## 4. `build-and-push.sh`

**Status:** ✅ Implemented (working tree, not yet committed)

**Purpose:** Build and push script for Docker images, supporting multiple variants.

**Code changes:**
- `build-and-push.sh` — New file

**Usage:**
```bash
# Build + push patches variant
docker login
./build-and-push.sh --variant patches

# Build only (no push)
./build-and-push.sh --variant patches --build-only

# Tag with version
./build-and-push.sh --variant patches --tag v4.3.6

# ARM64 only
./build-and-push.sh --variant patches --platform linux/arm64

# Dry run
./build-and-push.sh --variant patches --dry-run

# Build multiple variants
./build-and-push.sh --variant patches --variant core
```

**Variants:**

| Variant | Dockerfile | Description |
|---------|-----------|-------------|
| `patches` | `Dockerfile.kreuzberg` | Our patched image with all features |
| `core` | `docker/Dockerfile.core` | Upstream core image |
| `full` | `docker/Dockerfile.full` | Upstream full image |
| `cli` | `docker/Dockerfile.cli` | Upstream CLI-only image |

---

## Summary

| Feature | Status | File Changed | Upstream PR |
|---------|--------|-------------|-------------|
| `base_url` in structured extraction | ✅ Working tree | `handlers.rs` | — |
| `KREUZBERG_VLM_OCR_API_KEY` env var | ✅ Working tree | `env.rs` | — |
| `Dockerfile.kreuzberg` | ✅ Working tree | `Dockerfile.kreuzberg` | — |
| `build-and-push.sh` | ✅ Working tree | `build-and-push.sh` | — |

All patches are backward-compatible — they add optional parameters and env vars. Existing behavior is unchanged when the new options are not provided.