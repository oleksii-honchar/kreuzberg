# Spec: `KREUZBERG_VLM_OCR_API_KEY` Environment Variable

## Problem

Upstream Kreuzberg supports the following VLM OCR environment variables:

| Variable | Description |
|----------|-------------|
| `KREUZBERG_VLM_OCR_MODEL` | VLM model for vision-based OCR (e.g., `openai/gpt-4o`) |
| `KREUZBERG_VLM_EMBEDDING_MODEL` | LLM model for embedding generation |

**Missing:** `KREUZBERG_VLM_OCR_API_KEY` — There is no environment variable to set the API key specifically for VLM OCR. The API key must come from the general `KREUZBERG_LLM_API_KEY` or be configured programmatically.

This makes it impossible to use different API keys for VLM OCR vs structured extraction in containerized deployments.

## Solution

Add `KREUZBERG_VLM_OCR_API_KEY` environment variable support in `ExtractionConfig::from_env`.

### Changes

**File:** `crates/kreuzberg/src/core/config/extraction/env.rs`

1. Add `KREUZBERG_VLM_OCR_API_KEY` to the doc comment:
   ```rust
   /// - `KREUZBERG_VLM_OCR_API_KEY`: API key for the VLM OCR LLM provider
   ```

2. Add env var handling (inserted between `KREUZBERG_VLM_OCR_MODEL` and `KREUZBERG_VLM_EMBEDDING_MODEL`):
   ```rust
   // KREUZBERG_VLM_OCR_API_KEY override
   if let Ok(value) = std::env::var("KREUZBERG_VLM_OCR_API_KEY") {
       if value.is_empty() {
           return Err(KreuzbergError::Validation {
               message: "KREUZBERG_VLM_OCR_API_KEY must not be empty".to_string(),
               source: None,
           });
       }
       if self.ocr.is_none() {
           self.ocr = Some(OcrConfig::default());
       }
       if let Some(ref mut ocr) = self.ocr {
           if ocr.vlm_config.is_none() {
               ocr.vlm_config = Some(super::super::llm::LlmConfig {
                   model: String::new(),
                   api_key: Some(value),
                   base_url: None,
                   timeout_secs: None,
                   max_retries: None,
                   temperature: None,
                   max_tokens: None,
               });
           } else if let Some(ref mut vlm) = ocr.vlm_config {
               vlm.api_key = Some(value);
           }
       }
   }
   ```

### Environment Usage

```bash
# VLM OCR uses its own key
export KREUZBERG_VLM_OCR_MODEL="openai/gpt-4o"
export KREUZBERG_VLM_OCR_API_KEY="sk-vlm-..."

# Structured extraction uses a different key
export KREUZBERG_LLM_API_KEY="sk-extract-..."
```

### Backward Compatibility

- `KREUZBERG_VLM_OCR_API_KEY` is optional — when not set, behavior is identical to upstream.
- Empty values are rejected with a validation error (consistent with other env var handling in the file).
- If `ocr.vlm_config` already exists (e.g., from `KREUZBERG_VLM_OCR_MODEL`), the API key is merged into the existing config.
- If `ocr.vlm_config` does not exist, a new `LlmConfig` is created with only `api_key` set.

## Status

✅ Implemented (working tree)
