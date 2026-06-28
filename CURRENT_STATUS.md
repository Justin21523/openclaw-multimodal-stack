# Current Status — OpenClaw Multimodal Stack

Last updated: 2026-05-07

## Active Services

| Service | Status | Port | Notes |
|---------|--------|------|-------|
| llama-server.service | active (running) | 8080 | Gemma 4 31B + mmproj active |
| openclaw-gateway.service | active (running) | 18789 | v2026.5.6 |
| openclaw-model-control-ui.service | active (running) | 18888 | Includes Image Test endpoint |

## Active Model

- **Alias**: gemma31
- **Model**: `gemma-4-31B-it-Q4_K_M.gguf`
- **Path**: `/mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/`
- **Projector**: `mmproj-F16.gguf` (CPU offloaded via `--no-mmproj-offload`)
- **Context**: 131,072 tokens
- **Image Max Tokens**: 1,120
- **UBatch Size**: 1,152

## Verified Working

- [x] `GET /v1/models` reports multimodal capability
- [x] Direct llama.cpp image API (`/v1/chat/completions` with `image_url`)
- [x] Model Control UI Image Test (`POST /api/image-test` on port 18888)
- [x] `openclaw infer image describe <path>`
- [x] `openclaw config validate`
- [x] Text chat on all three models (gemma31, qwen27, qwen35)

## Known Issues

### Issue 1 — ACTIVE: `[chat.history omitted: message too large]`
- **Severity**: High — breaks image analysis through normal webchat UI
- **Root cause**: Identified — see `CHAT_HISTORY_OMITTED_INVESTIGATION.md`
- **Status**: Diagnosis complete, patch pending approval
- **Impact**: Webchat image sends work for the first turn only; subsequent turns receive the placeholder

### Issue 2 — ACTIVE: `400 Failed to tokenize prompt` (embedded agent)
- **Severity**: Medium — embedded agent runs fail when tool/schema payload is too large
- **Root cause**: Bootstrap files (AGENTS.md 13,666 chars) truncated but still exceed Gemma 4 tokenizer limits
- **Status**: Under investigation

### Issue 3 — PENDING: No Qwen VLM profile
- **Severity**: Low — Qwen3.6 text models work; VLM capability not yet added
- **Status**: Research in progress — see `QWEN_VLM_RESEARCH_REPORT.md`

## Model Inventory on Disk

| Alias | Path | Size | Type |
|-------|------|------|------|
| gemma31 | `/mnt/c/ai_models/language/vlm/gemma-4-31B-it-GGUF/` | ~20GB | VLM |
| qwen27 | `/mnt/c/ai_models/language/llm/Qwen3.6-27B-GGUF/` | ~16GB | Text-only |
| qwen35 | `/mnt/c/ai_models/language/llm/Qwen3.6-35B-A3B-GGUF/` | ~22GB | Text-only (MoE) |
| — | Qwen VLM | not downloaded | Pending |

## Endpoints

| URL | Purpose |
|-----|---------|
| http://127.0.0.1:8080 | llama.cpp UI + API |
| http://127.0.0.1:8080/v1/chat/completions | Direct inference API |
| http://127.0.0.1:8080/v1/models | Model list |
| http://127.0.0.1:18789 | OpenClaw Gateway / WebUI |
| http://127.0.0.1:18888 | Model Control UI (switch models, image test) |
