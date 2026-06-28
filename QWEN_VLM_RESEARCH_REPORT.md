# Qwen VLM Research Report

Last updated: 2026-05-07

## Executive Summary

| Question | Answer |
|----------|--------|
| Can Qwen3.6-27B / 35B-A3B become multimodal via llama.cpp --mmproj? | **NO** |
| Does a usable Qwen VLM for llama.cpp exist? | **YES — Qwen2.5-VL** |
| Best Qwen VLM for R9700 32GB? | **Qwen2.5-VL-32B-Instruct Q4_K_M (~20 GB)** |
| Does Qwen3-VL exist as of May 2026? | **No confirmed release** |

---

## Section 1: Qwen3.6 Text Models — NOT Suitable for VLM via mmproj

### Current Models on Disk

| Alias | File | Type | Path |
|-------|------|------|------|
| qwen27 | `Qwen3.6-27B-Q4_K_M.gguf` | Text-only | `/mnt/c/ai_models/language/llm/Qwen3.6-27B-GGUF/` |
| qwen35 | `Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf` | Text-only MoE | `/mnt/c/ai_models/language/llm/Qwen3.6-35B-A3B-GGUF/` |

### Why These Cannot Become Multimodal

llama.cpp multimodal (`--mmproj`) requires a **separate vision projector file** that is produced during training when the vision encoder is designed as a detached component from the LLM backbone. Qwen3.6 27B and 35B-A3B are **dense text LLMs / MoE text LLMs** — they have no vision encoder in their architecture.

Even if a Qwen3.x model has integrated vision capability (as in some Qwen3.x VL variants), it would require full model quantization with the integrated vision encoder — not a separable mmproj file. llama.cpp's `--mmproj` approach specifically requires the projector to be a separate GGUF.

**Conclusion**: Do NOT set `supportsImages: true` for qwen27 or qwen35. There is no compatible mmproj for these models. Any attempt would silently fail or produce garbage output.

---

## Section 2: Qwen2.5-VL — The Correct Qwen VLM Option

### What It Is

Qwen2.5-VL is Alibaba's Qwen 2.5 generation vision-language model series. It uses a separate vision encoder + projector architecture that is compatible with llama.cpp's `--mmproj` workflow.

### Available Sizes

| Size | Q4_K_M VRAM | Q6_K VRAM | Q8_0 VRAM | R9700 32GB Fit? |
|------|-------------|-----------|-----------|-----------------|
| 7B   | ~5.5 GB    | ~7.7 GB   | ~10 GB    | Yes (easily) |
| 32B  | ~20 GB     | ~27 GB    | ~35 GB    | Yes (Q4_K_M) |
| 72B  | ~43 GB     | —         | —         | No (exceeds 32GB) |

**Recommended for R9700 32GB**: `Qwen2.5-VL-32B-Instruct` at `Q4_K_M` (~20 GB model + ~1 GB mmproj = ~21 GB total)

### HuggingFace Sources

- **lmstudio-community**: `lmstudio-community/Qwen2.5-VL-32B-Instruct-GGUF`
- **bartowski**: `bartowski/Qwen2.5-VL-32B-Instruct-GGUF`
- **Original (non-GGUF)**: `Qwen/Qwen2.5-VL-32B-Instruct`

### mmproj File

For Qwen2.5-VL GGUF releases, the projector file is included in the same repo, typically named:
- `mmproj-Qwen2.5-VL-32B-Instruct-f16.gguf`
- Or `mmproj-model-f16.gguf`

Always use the F16 projector (not quantized) for maximum image quality.

### Recommended Launch Flags for R9700 32GB

```bash
--mmproj /mnt/c/ai_models/language/vlm/qwen/Qwen2.5-VL-32B/mmproj-Qwen2.5-VL-32B-f16.gguf
--no-mmproj-offload          # keep projector on CPU (same as Gemma setup)
--ctx-size 32768             # conservative context for 32B + 32GB VRAM
--n-gpu-layers 99            # max GPU offload for LLM backbone
--image-max-tokens 1024      # token budget for vision tokens
--ubatch-size 1024
```

**Why `--no-mmproj-offload`**: At 131K context, the KV cache for a 32B model already uses most of the 32GB VRAM. Keeping the projector on CPU (a few hundred MB) avoids OOM. The projector only runs once per image, so CPU penalty is minimal.

### Context Size Recommendation

- **Conservative (recommended)**: 32,768 tokens
- **Maximum (risky)**: 65,536 tokens
- **Do not use 131,072 tokens** — combined VRAM for 32B model + KV cache + image tokens will exceed 32 GB

### Comparison: Qwen2.5-VL-7B vs 32B

| Aspect | 7B | 32B |
|--------|----|----|
| VRAM (Q4_K_M) | ~5.5 GB | ~20 GB |
| Image quality | Good for casual analysis | Excellent — comparable to frontier models |
| Context | 128K | 128K |
| Speed (R9700) | ~40-60 tok/s | ~12-20 tok/s |
| Recommendation | Secondary/fast profile | Primary VLM profile |

---

## Section 3: Qwen3-VL Status

As of May 2026, **no confirmed Qwen3-VL release** has been found:
- Qwen3 series focuses on text and MoE text models
- Qwen3.6 variants (27B, 35B-A3B) are text models placed in `/language/llm/`
- No Qwen3-VL GGUF repos were found on HuggingFace

**Recommendation**: Proceed with Qwen2.5-VL-32B. If Qwen3-VL is released in the future, evaluate at that time.

---

## Section 4: Comparison with Gemma 4 VLM

| Aspect | Gemma 4 31B (Current) | Qwen2.5-VL 32B (Candidate) |
|--------|-----------------------|---------------------------|
| VRAM (Q4_K_M) | ~20 GB | ~20 GB |
| mmproj | F16, CPU (240 MB) | F16, CPU (~300 MB) |
| Context | 131,072 (large) | 32,768 (conservative) |
| Image quality | Excellent (Gemma 4 multimodal) | Excellent |
| Language | Multilingual | Multilingual + strong Chinese |
| Tool use | Limited (400 tokenize errors) | Strong Qwen3-class tool support |
| Status | Active — DO NOT CHANGE | Candidate — pending download approval |

---

## Section 5: Storage Plan for Qwen VLM

```
/mnt/c/ai_models/language/vlm/qwen/
└── Qwen2.5-VL-32B/
    ├── Qwen2.5-VL-32B-Instruct-Q4_K_M.gguf   (~20 GB)
    └── mmproj-Qwen2.5-VL-32B-f16.gguf         (~300 MB)
```

Total download: ~20.3 GB. Requires explicit approval before downloading.

---

## Section 6: Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Qwen2.5-VL mmproj not compatible with current llama.cpp build | Medium | Validate with `llama-server --mmproj --version` before service integration |
| KV cache OOM at 32B + 32768 ctx | Low | Start at 16K ctx if needed |
| Image quality worse than Gemma 4 | Low | Run side-by-side comparison first |
| Breaks existing Gemma VLM | None | Separate profile, no config change to gemma31 |
| Model too slow for interactive use | Low | 7B variant available as fallback |

---

## Conclusion

1. **Qwen3.6-27B and Qwen3.6-35B-A3B are text-only for the purposes of llama.cpp multimodal.** Do not attempt to add mmproj.
2. **Qwen2.5-VL-32B-Instruct at Q4_K_M is the correct Qwen VLM choice** for R9700 32GB.
3. A separate `qwen-vlm` profile should be created without touching the Gemma VLM or text Qwen profiles.
4. Download and validation require explicit user approval.
5. No Qwen3-VL equivalent is available as of May 2026.
