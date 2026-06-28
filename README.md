# OpenClaw Multimodal Stack

AMD Radeon AI PRO R9700 (32GB HBM) — ROCm / llama.cpp multimodal investigation workspace.

## Purpose

This workspace documents the investigation and implementation plan for:

1. Fixing `[chat.history omitted: message too large]` in OpenClaw image analysis flows
2. Stabilizing the Gemma 4 31B VLM profile
3. Adding a Qwen-family VLM profile (Qwen3.6 or Qwen2.5-VL)

## Current Active Setup

- **Active model**: Gemma 4 31B IT Q4_K_M (`gemma31`)
- **Image support**: Working via direct API and Model Control UI
- **WebChat image**: Broken for multi-turn (see investigation)
- **Services**: llama-server:8080, openclaw-gateway:18789, model-control-ui:18888

## Quick Links

| Document | Purpose |
|----------|---------|
| `CURRENT_STATUS.md` | Active service state and known issues |
| `CHAT_HISTORY_OMITTED_INVESTIGATION.md` | Root cause analysis + fix plan |
| `OPENCLAW_IMAGE_PIPELINE_FIX_PLAN.md` | Detailed implementation of image fix |
| `GEMMA_VLM_STABILITY_PLAN.md` | Gemma config reference + restore guide |
| `QWEN_VLM_RESEARCH_REPORT.md` | Qwen VLM compatibility research |
| `QWEN_VLM_IMPLEMENTATION_PLAN.md` | Qwen VLM setup steps (pending approval) |
| `MULTIMODAL_ARCHITECTURE.md` | System architecture diagram |
| `SERVICE_PROFILES.md` | Service configs for all model profiles |
| `VALIDATION_PLAN.md` | Test matrix for all profiles |
| `ROLLBACK_PLAN.md` | Rollback procedures for every change |

## Safety Rules

1. Never overwrite working Gemma multimodal service without backup
2. Never modify text-only Qwen3.6 metadata to pretend it supports images unless mmproj is confirmed
3. Never break llama-server.service — always keep `restart gemma31` as the recovery path
4. All config changes require backup first (see ROLLBACK_PLAN.md)
5. Do not touch CUDA environments

## Execution Order

1. Phase 0: Read-only audit ✅ Complete
2. Phase 1: Fix `[chat.history omitted]` — awaiting approval
3. Phase 2: Qwen VLM research ✅ Complete
4. Phase 3: Qwen VLM download + profile — awaiting approval
5. Phase 4: Validation across all profiles
