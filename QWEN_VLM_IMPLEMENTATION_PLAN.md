# Qwen VLM Implementation Plan

Status: PENDING APPROVAL

## Selected Model

**Qwen2.5-VL-32B-Instruct** at Q4_K_M quantization

- Source: `lmstudio-community/Qwen2.5-VL-32B-Instruct-GGUF`
- Language model: `Qwen2.5-VL-32B-Instruct-Q4_K_M.gguf` (~20 GB)
- Projector: `mmproj-Qwen2.5-VL-32B-Instruct-f16.gguf` (~300 MB)
- Context: 32,768 tokens (conservative for 32GB VRAM)
- Storage: `/mnt/c/ai_models/language/vlm/qwen/Qwen2.5-VL-32B/`

## Why This Model

1. Fits in R9700 32GB VRAM at Q4_K_M (~20 GB model + ~10 GB KV cache at 32K ctx ≈ 30 GB)
2. Compatible with llama.cpp `--mmproj` (separate vision projector)
3. Strong multilingual + Chinese image understanding
4. Does not replace Gemma VLM — separate alias `qwenvlm32`
5. Similar inference speed to Gemma 4 31B (~15-20 tok/s on R9700)

## Phase 1: Download (Requires Explicit Approval)

```bash
# Create target directory
mkdir -p /mnt/c/ai_models/language/vlm/qwen/Qwen2.5-VL-32B

# Download main model
huggingface-cli download \
  lmstudio-community/Qwen2.5-VL-32B-Instruct-GGUF \
  Qwen2.5-VL-32B-Instruct-Q4_K_M.gguf \
  --local-dir /mnt/c/ai_models/language/vlm/qwen/Qwen2.5-VL-32B

# Download projector (smaller, download first to test)
huggingface-cli download \
  lmstudio-community/Qwen2.5-VL-32B-Instruct-GGUF \
  mmproj-Qwen2.5-VL-32B-Instruct-f16.gguf \
  --local-dir /mnt/c/ai_models/language/vlm/qwen/Qwen2.5-VL-32B
```

**Do NOT run this until explicitly approved.**

## Phase 2: Register in Model Catalog

Add to `/mnt/c/ai_projects/gpu-migration-r9700/configs/llamacpp-model-candidates.json`:

```json
"qwenvlm32": {
  "id": "Qwen2.5-VL-32B-Instruct-Q4_K_M.gguf",
  "label": "Qwen2.5-VL 32B Q4_K_M (multimodal)",
  "role": "candidate",
  "path": "/mnt/c/ai_models/language/vlm/qwen/Qwen2.5-VL-32B/Qwen2.5-VL-32B-Instruct-Q4_K_M.gguf",
  "mmproj": "/mnt/c/ai_models/language/vlm/qwen/Qwen2.5-VL-32B/mmproj-Qwen2.5-VL-32B-Instruct-f16.gguf",
  "contextWindow": 32768,
  "maxTokens": 4096,
  "supportsImages": true
}
```

## Phase 3: Add OpenClaw Model Metadata

Add to `models.providers.llamacpp.models` in `openclaw.json`:

```json
{
  "id": "Qwen2.5-VL-32B-Instruct-Q4_K_M.gguf",
  "name": "Qwen2.5-VL-32B Q4_K_M (multimodal / ROCm / R9700)",
  "contextWindow": 32768,
  "contextTokens": 32768,
  "maxTokens": 4096,
  "input": ["text", "image"],
  "reasoning": false,
  "cost": {"cacheRead": 0, "cacheWrite": 0, "input": 0, "output": 0},
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

## Phase 4: Test (Direct API First)

```bash
# Switch to qwenvlm32 (does NOT restart service — only updates .env)
bash /mnt/c/ai_projects/gpu-migration-r9700/scripts/12_llamacpp_model_control.sh set qwenvlm32

# Restart service
systemctl --user restart llama-server.service
sleep 20  # wait for model load

# Test 1: model reports multimodal
curl -s http://127.0.0.1:8080/v1/models | jq '.'

# Test 2: direct image API
curl -s -X POST http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2.5-VL-32B-Instruct-Q4_K_M.gguf",
    "messages": [{"role": "user", "content": [
      {"type": "text", "text": "What is in this image?"},
      {"type": "image_url", "image_url": {"url": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="}}
    ]}],
    "max_tokens": 100
  }'

# Test 3: Model Control UI image test
# Open http://127.0.0.1:18888 and use Image Test tab

# Test 4: openclaw infer
openclaw infer image describe test_images/test_photo.jpg
```

## Phase 5: If Qwen2.5-VL Projector Name Differs

When the actual GGUF file is downloaded, verify the exact mmproj filename:

```bash
ls /mnt/c/ai_models/language/vlm/qwen/Qwen2.5-VL-32B/mmproj*.gguf
```

Update the catalog entry if the filename differs from the expected value.

## Phase 6: Switch Back to Gemma After Testing

After validation, switch back to Gemma as the active model:

```bash
bash /mnt/c/ai_projects/gpu-migration-r9700/scripts/12_llamacpp_model_control.sh restart gemma31
```

The qwenvlm32 alias remains registered and can be activated any time.

## Safety Guarantees

- Gemma VLM profile (`gemma31`) is never modified
- Qwen text profiles (`qwen27`, `qwen35`) remain unchanged
- New alias `qwenvlm32` is purely additive
- All changes to `openclaw.json` are backed up first
- Service can always be restored with `restart gemma31`

## Approval Required Before

- [ ] Downloading Qwen2.5-VL-32B files (~20.3 GB)
- [ ] Adding qwenvlm32 to model catalog
- [ ] Switching active model to qwenvlm32
- [ ] Adding model to openclaw.json metadata
