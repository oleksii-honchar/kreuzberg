# Spec: `base_url` in Structured Extraction API Handler

## Problem

The upstream Kreuzberg `/extract/structured` API endpoint accepts the following multipart form fields for LLM configuration:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `model` | string | Yes | LLM model identifier (e.g., `openai/gpt-4o`) |
| `api_key` | string | No | API key for the LLM provider |
| `prompt` | string | No | Custom Jinja2 prompt template |
| `strict` | boolean | No | Enable strict mode |
| `schema_name` | string | No | Schema name (default: `"extraction"`) |

**Missing:** `base_url` — There is no way to override the base URL for the LLM provider through the API. The `LlmConfig.base_url` field exists in the codebase but is hardcoded to `None` in the handler.

This prevents routing LLM calls through custom endpoints, proxies, or local inference servers.

## Solution

Add `base_url` as an optional multipart form field to the `/extract/structured` endpoint.

### Changes

**File:** `crates/kreuzberg/src/api/handlers.rs`

1. Add `base_url` to the doc comment:
   ```rust
   /// - `base_url`: Base URL for the LLM provider (optional)
   ```

2. Add `base_url` variable:
   ```rust
   let mut base_url: Option<String> = None;
   ```

3. Add `base_url` field parsing in the multipart form handler:
   ```rust
   "base_url" => {
       base_url = Some(
           field
               .text()
               .await
               .map_err(|e| ApiError::validation(crate::error::KreuzbergError::validation(e.to_string())))?,
       );
   }
   ```

4. Pass `base_url` to `LlmConfig`:
   ```rust
   // Before
   base_url: None,
   // After
   base_url,
   ```

### API Usage

```bash
curl -X POST http://localhost:3000/extract/structured \
  -F "file=@document.pdf" \
  -F "schema={\"type\": \"object\", \"properties\": {\"title\": {\"type\": \"string\"}}}" \
  -F "model=openai/gpt-4o" \
  -F "api_key=sk-..." \
  -F "base_url=https://my-custom-proxy.example.com" \
  -F "strict=true"
```

### Backward Compatibility

- `base_url` is optional — when not provided, `LlmConfig.base_url` remains `None`, preserving upstream behavior.
- No changes to the `LlmConfig` struct or `liter-llm` integration.

## Status

✅ Implemented (working tree)
