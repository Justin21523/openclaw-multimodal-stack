# Multimodal Architecture

## System Overview

```
User (WebChat / CLI)
        │
        ▼
OpenClaw Gateway (port 18789)
        │
        ├──── Text chat ──────────────────────────────────────────┐
        │                                                          │
        ├──── Image via webchat attachment                         │
        │     (stored as base64 in history → HITS 128KB LIMIT)    │
        │                                                          │
        └──── /img skill (NEW — bypasses history)                  │
              │                                                     │
              ▼                                                     │
      Model Control UI (port 18888)                                │
              │                                                     │
              └──── /api/image-test ────────────────────────────── │
                                                                    │
                                                                    ▼
                                              llama-server (port 8080)
                                              Gemma 4 31B + mmproj
                                              (or Qwen2.5-VL-32B — future)
```

## Image Inference Paths

### Path 1 — Webchat Native (BROKEN for multi-turn)

```
User uploads image in webchat
  → OpenClaw stores image as base64 data URL in chat history message (~1.5 MB)
  → On next turn: replaceOversizedChatHistoryMessages() checks each message
  → 1.5 MB > 128 KB (CHAT_HISTORY_MAX_SINGLE_MESSAGE_BYTES) → replaced with placeholder
  → llama.cpp receives: "[chat.history omitted: message too large]"
  → RESULT: Image lost after Turn 1
```

### Path 2 — Model Control UI `/api/image-test` (WORKING)

```
Model Control UI receives image + prompt
  → Constructs single-turn request (no history)
  → POST http://127.0.0.1:8080/v1/chat/completions
  → llama.cpp processes image + prompt
  → Returns text analysis
```

### Path 3 — CLI Direct Inference (WORKING)

```
openclaw infer image describe <path>
  → Single-turn inference with file path
  → No history involved
  → Direct to llama.cpp
```

### Path 4 — /img Skill (PROPOSED FIX)

```
User types /img [prompt] in webchat
  → skill reads latest image from ~/.openclaw/media/inbound/
  → skill calls http://127.0.0.1:18888/api/image-test
  → Returns text analysis as chat reply
  → Only TEXT is stored in history — image data never enters history
  → RESULT: Multi-turn conversation about image works correctly
```

## Memory Limit Hierarchy

```
Per-request HTTP payload limit:         25 MB  (MAX_PAYLOAD_BYTES)
Max buffered bytes:                     50 MB  (MAX_BUFFERED_BYTES)
Total chat history budget:               6 MB  (maxChatHistoryMessagesBytes) ← hardcoded
Per-message max before replace:        128 KB  (CHAT_HISTORY_MAX_SINGLE_MESSAGE_BYTES) ← hardcoded
Max inline image (base64 decoded):    ~1.43 MB  (MAX_WEBCHAT_IMAGE_DATA_BYTES)
Max data URL string length:            2 M chars (MAX_WEBCHAT_IMAGE_DATA_URL_CHARS)
Text history char limit (webchat):    50,000    (gateway.webchat.chatHistoryMaxChars) ← configurable
Tool-path image max size:             50 MB     (tools.media.image.maxBytes) ← configurable
```

## Model Profiles

| Profile | Alias | Type | Context | Image | Status |
|---------|-------|------|---------|-------|--------|
| gemma31 | gemma31 | VLM | 131,072 | Yes | Active |
| qwen27 | qwen27 | Text | 131,072 | No | Active |
| qwen35 | qwen35 | Text/MoE | 262,144 | No | Active |
| qwenvlm32 | qwenvlm32 | VLM | 32,768 | Yes | Pending download |

## llama.cpp Multimodal Architecture

```
llama-server
├── LLM backbone: Gemma 4 31B (GPU — n-gpu-layers 99)
│   └── ~20 GB VRAM
├── Vision projector: mmproj-F16.gguf (CPU — --no-mmproj-offload)
│   └── ~240 MB RAM
├── KV cache: ctx=131072 (GPU VRAM)
│   └── ~9-10 GB VRAM
└── media-path: ~/.openclaw/media/inbound (local file reference support)

Total VRAM: ~28-30 GB of 34.2 GB available
```

## OpenClaw Service Architecture

```
openclaw-gateway.service (18789)
└── Node.js — compiled bundle
    ├── chat.ts — history trimming (128KB limit hardcoded)
    ├── session-utils.ts — transcript files
    ├── provider/llamacpp — API calls to port 8080
    └── skills — custom /commands

openclaw-model-control-ui.service (18888)
└── Node.js — server.js (our custom code)
    ├── GET  /api/status
    ├── POST /api/set
    ├── POST /api/restart
    └── POST /api/image-test  ← key bypass endpoint

llama-server.service (8080)
└── C++ llama-server binary
    ├── Gemma 4 31B Q4_K_M model
    ├── mmproj projector (CPU)
    └── media-path inbound dir
```
