# Gemma VLM Stability Plan

## Current State (Verified Working)

The Gemma 4 31B multimodal setup is confirmed working. This document records its configuration for stability and recovery.

## Active Configuration

### llamacpp-active.env

```bash
LLAMACPP_ACTIVE_ALIAS=gemma31
LLAMACPP_ACTIVE_MODEL=/mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/gemma-4-31B-it-Q4_K_M.gguf
LLAMACPP_ACTIVE_MODEL_ID=gemma-4-31B-it-Q4_K_M.gguf
LLAMACPP_ACTIVE_CTX=131072
LLAMACPP_ACTIVE_MAX_TOKENS=8192
LLAMACPP_ACTIVE_SUPPORTS_IMAGES=true
LLAMACPP_ACTIVE_MMPROJ=/mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/mmproj-F16.gguf
LLAMACPP_IMAGE_MAX_TOKENS=1120
```

### Effective llama-server Launch Command

```bash
/mnt/c/ai_tools/llama.cpp-rocm/build/bin/llama-server \
  -m /mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/gemma-4-31B-it-Q4_K_M.gguf \
  --port 8080 \
  --ctx-size 131072 \
  --n-gpu-layers 99 \
  --host 0.0.0.0 \
  --reasoning off \
  --reasoning-budget 0 \
  --parallel 1 \
  --batch-size 2048 \
  --ubatch-size 1152 \
  --cache-ram 0 \
  --poll 0 \
  --poll-batch 0 \
  --sleep-idle-seconds -1 \
  --log-prefix \
  --mmproj /mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/mmproj-F16.gguf \
  --media-path /home/justin/.openclaw/media/inbound \
  --no-mmproj-offload \
  --image-max-tokens 1120
```

### VRAM Usage Profile

| Component | Approximate VRAM |
|-----------|-----------------|
| Model weights (Q4_K_M 31B) | ~18-20 GB |
| KV cache at ctx=131072 | ~9-10 GB |
| Total | ~28-30 GB |

The mmproj projector runs on **CPU** (`--no-mmproj-offload`). It uses ~240 MB of RAM, not VRAM. This is intentional to avoid OOM at 131K context.

### Why --no-mmproj-offload

At context size 131,072, the KV cache for a 31B model requires approximately 9-10 GB of VRAM. The R9700 has 34.2 GB HBM. Without offloading the projector (~240 MB), total VRAM use is ~28-30 GB — safe. With projector on GPU, marginal OOM risk at peak usage. CPU projection adds only ~0.5s per image, acceptable.

## Model Files

| File | Path | Size | Purpose |
|------|------|------|---------|
| gemma-4-31B-it-Q4_K_M.gguf | `/mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/` | ~20 GB | LLM weights |
| mmproj-F16.gguf | `/mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/` | ~240 MB | Vision projector |

## OpenClaw Model Metadata (openclaw.json)

```json
{
  "id": "gemma-4-31B-it-Q4_K_M.gguf",
  "name": "Gemma-4-31B-IT Q4_K_M (multimodal via llama.cpp mmproj)",
  "contextWindow": 131072,
  "contextTokens": 131072,
  "maxTokens": 8192,
  "input": ["text", "image"],
  "compat": {
    "supportsTools": true,
    "supportsUsageInStreaming": true,
    "supportsReasoningEffort": false,
    "supportsStrictMode": false,
    "thinkingFormat": "openrouter",
    "maxTokensField": "max_tokens"
  }
}
```

## Known Limitation: Tool Use Tokenization Error

When the embedded agent sends complex tool+schema payloads, Gemma 4 occasionally returns:
```
400 Failed to tokenize prompt
```

This is caused by AGENTS.md (13,666 chars) and other bootstrap files exceeding the injected context budget. It is a **separate issue from image analysis** and does not affect direct image inference.

Workaround (in place): bootstrap files are truncated to 650 chars in injected context. The error still occurs occasionally for complex tool calls. This is a known limitation of using Gemma 4 as the embedded agent model.

## Hardening Rules

1. **Never set `supportsImages: true` for qwen27 or qwen35** — they have no mmproj
2. **Never remove `--no-mmproj-offload`** without testing VRAM budget first
3. **Never increase `--ubatch-size` beyond 1152** without re-testing OOM behavior
4. **Never change the mmproj path** without verifying the file exists
5. **Always back up `llamacpp-active.env`** before any model switch
6. **Restore command**: `bash scripts/12_llamacpp_model_control.sh restart gemma31`

## Restore Procedure

If the Gemma VLM service breaks after any change:

```bash
# 1. Restore the active env from catalog
cd /mnt/c/ai_projects/gpu-migration-r9700
bash scripts/12_llamacpp_model_control.sh set gemma31

# 2. Restart service
systemctl --user restart llama-server.service

# 3. Verify
curl -s http://127.0.0.1:8080/v1/models | jq '.data[0].id'
# Expected: "gemma-4-31B-it-Q4_K_M.gguf"

# 4. Test image API
curl -s -X POST http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma-4-31B-it-Q4_K_M.gguf",
    "messages": [{"role": "user", "content": [
      {"type": "text", "text": "What is in this image?"},
      {"type": "image_url", "image_url": {"url": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="}}
    ]}],
    "max_tokens": 50
  }' | jq '.choices[0].message.content'
```
