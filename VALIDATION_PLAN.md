# Validation Plan

## Test Matrix

### Profile: Gemma VLM (gemma31) — Existing

| # | Test | Command / Action | Expected Result | Status |
|---|------|-----------------|----------------|--------|
| G1 | Model reports multimodal | `curl -s http://127.0.0.1:8080/v1/models \| jq '.data[0]'` | `input: ["text","image"]` | ✅ Verified |
| G2 | Direct image API | `curl` with base64 image | Text description returned | ✅ Verified |
| G3 | Model Control UI image test | POST `/api/image-test` | Analysis returned | ✅ Verified |
| G4 | CLI image inference | `openclaw infer image describe <path>` | Analysis returned | ✅ Verified |
| G5 | Text chat | Normal chat via WebUI | Response generated | ✅ Verified |
| G6 | Multi-turn image chat | Image → follow-up text | **FAILS** (128KB limit) | ❌ Known issue |
| G7 | /img skill | `/img describe this image` | Analysis as text reply | 🔲 Pending impl |
| G8 | Service restart stability | `restart gemma31` | Model loads, responds | ✅ Verified |

### Profile: Qwen Text-only (qwen27, qwen35) — Existing

| # | Test | Expected Result | Status |
|---|------|----------------|--------|
| Q1 | Text chat qwen27 | Response generated | ✅ Verified |
| Q2 | Text chat qwen35 | Response generated | ✅ Verified |
| Q3 | qwen27 does NOT accept images | 400 or error | ✅ supportsImages=false |
| Q4 | Model switch qwen27↔qwen35 | Service restarts correctly | ✅ Verified |

### Profile: Qwen VLM (qwenvlm32) — Pending

| # | Test | Command | Expected Result | Status |
|---|------|---------|----------------|--------|
| QV1 | Model reports multimodal | `/v1/models` | `input: ["text","image"]` | 🔲 Pending download |
| QV2 | Direct image API | curl with base64 | Description returned | 🔲 Pending |
| QV3 | Model Control UI image test | `/api/image-test` | Analysis returned | 🔲 Pending |
| QV4 | CLI inference | `openclaw infer image describe` | Analysis returned | 🔲 Pending |
| QV5 | Context size safe at 32K | Load model, check VRAM | <32 GB | 🔲 Pending |
| QV6 | Switch back to gemma31 | `restart gemma31` | Gemma loads | 🔲 Pending |
| QV7 | Text chat with qwenvlm32 | Normal text message | Response generated | 🔲 Pending |

### Image Pipeline Fix Validation

| # | Test | Steps | Expected Result | Status |
|---|------|-------|----------------|--------|
| F1 | /img skill creates and responds | Upload image, type `/img` | Analysis as text | 🔲 Pending impl |
| F2 | Multi-turn after /img | /img → follow-up text | Text reply works (no placeholder) | 🔲 Pending |
| F3 | /img on empty inbound dir | Type `/img` with no uploaded image | Error message | 🔲 Pending |
| F4 | Large image handling (>5MB) | Upload large image, /img | Size error message | 🔲 Pending |
| F5 | Existing paths unaffected | Direct API test after skill installed | Still works | 🔲 Pending |

## Validation Scripts

### Quick smoke test (all services)

```bash
bash /mnt/c/ai_projects/openclaw-multimodal-stack/scripts/12_validate_all_multimodal_profiles.sh
```

### Gemma VLM direct test

```bash
bash /mnt/c/ai_projects/openclaw-multimodal-stack/scripts/02_test_gemma_vlm_direct_llamacpp_api.sh
```

### Image pipeline fix test

```bash
bash /mnt/c/ai_projects/openclaw-multimodal-stack/scripts/04_test_gemma_vlm_openclaw_infer.sh
```

## Test Image Required

Place at: `/mnt/c/ai_projects/openclaw-multimodal-stack/test_images/test_photo.jpg`

A simple test image (photo of any object) is sufficient. Must be <5 MB.

## Acceptance Criteria

All tests pass before declaring any phase complete:

- Phase 1 (Image pipeline fix): G7, F1, F2, F3, F4, F5 all pass
- Phase 2 (Qwen VLM): QV1–QV7 all pass
- Regression: G1–G5, Q1–Q4 still pass after each phase
